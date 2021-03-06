clear all; close all;
fprintf('Prepare for the original image : I binary image : bI\n');
load('zebraI.mat');

% The first input variable I is inside op1resample.mat 
% load('op1resample.mat');
outfilename = 'op1resample.swc';


% The second input variable is plot
plot_value = false;

% The third input variable is percentage 
percentage = 0.98;

% The fourth input vairable is rewire
rewire =  false;

% The fifth input vairable is gap 
gap = 10;

% The sixth input variable is ax
ax_value = false;

% The seventh input variable is dumpcheck
dumpcheck = true;

% The eighth input variable is connectrate
connectrate = 1.5;

% The ninth input variable is branchlen
branchlen = 8;

% The tenth input variable is somagrowthcheck
somagrowthcheck = false;

% The eleventh input vairable is soma structure
% We only test the anisotropic fast marching at this point 
% so we do not include soma in this script 

% The twelfth input variable is cleanercheck
cleanercheck = false;

% The thirteenth input variable is dtimageflag
dtimageflag = false;

% The fourteenth input variable is tmapflag
atmapflag = true;

% The fifthteenth input variable is igonoreradiusflag
igonoreradiusflag = true;

threshold = 56;

I_original = I;

I = I > threshold;
    % if plot
    %     axes(ax);
    % end
    if (~dtimageflag)
        disp('Distance transform');
        notbI = not(I>0.5);
        bdist = bwdist(notbI, 'Quasi-Euclidean');
        bdist = bdist .* double(I);
        bdist = double(bdist);
    end

    disp('Looking for the source point...')
    if somagrowthcheck
        SourcePoint = [soma.x; soma.y; soma.z];
        somaidx = find(soma.I == 1);
        [somax, somay, somaz] = ind2sub(size(soma.I), somaidx);
        % Find the soma radius
        d = pdist2([somax, somay, somaz], [soma.x, soma.y, soma.z]);
        maxD = max(d);
    else
        [SourcePoint, maxD] = maxDistancePoint(bdist, I, true);
        fprintf('SourcePoint x: %d, SourcePoint y: %d, SourcePoint z: %d\n', SourcePoint(1), SourcePoint(2), SourcePoint(3));
    end
    disp('Make the speed image...')
    SpeedImage=(bdist/maxD).^4;
    % clear bdist;
    
    SpeedImage(SpeedImage==0) = 1e-10;
	% if plot
 %        axes(ax);
	% end	
	disp('marching...');
    if (~atmapflag)
        T = msfm(SpeedImage, SourcePoint, false, false);
    else
        T = afm(I_original, threshold);
    end
    save('T_rivulet_afm.mat','T');

    szT = size(T);
    fprintf('the size of time map, x is : %d, y is : %d, z is : %d\n', szT(1), szT(2), szT(3));
    disp('Finish marching')

    if somagrowthcheck
        fprintf('Mark soma label on time-crossing map\n')
        T(soma.I==1) = -2;
    end

    if plot_value
    	hold on 
    end

    tree = []; % swc tree
    if somagrowthcheck
        fprintf('Initialization of swc tree.\n'); 
        tree(1, 1) = 1;
        tree(1, 2) = 2;
        tree(1, 3) = soma.x;
        tree(1, 4) = soma.y;
        tree(1, 5) = soma.z;
        % fprintf('source point x : %d, y : %d, z : %d.\n', uint8(SourcePoint(1)), uint8(SourcePoint(2)), uint8(SourcePoint(3)));         
        tree(1, 6) = 1;
        tree(1, 7) = -1;
    end

    prune = true;
	% Calculate gradient of DistanceMap
	disp('Calculating gradient...')
    grad = distgradient(T);
    % if plot
    %     axes(ax);
    % end
    S = {};
    B = zeros(size(T));
    if somagrowthcheck
        B = B | (soma.I>0.5);
    end
    lconfidence = [];
    if plot_value
	    [x,y,z] = sphere;
	    plot3(x + SourcePoint(2), y + SourcePoint(1), z + SourcePoint(3), 'ro');
	end

    unconnectedBranches = {};
    printcount = 0;
    printn = 0;
    counter = 1;
    figure
    while(true)

	    StartPoint = maxDistancePoint(T, I, true);

% 	    if plot_value
% 		    plot3(x + StartPoint(2), y + StartPoint(1), z + StartPoint(3), 'ro');
% 		end

	    if T(StartPoint(1), StartPoint(2), StartPoint(3)) == 0 || I(StartPoint(1), StartPoint(2), StartPoint(3)) == 0
	    	break;
	    end

	    [l, dump, merged, somamerged] = shortestpath2(T, grad, I, tree, StartPoint, SourcePoint, 1, 'rk4', gap);
        if plot_value
		    plot3(l(1,:), l(2,:), l(3,:), 'ro');
		end
        if size(l, 1) == 0
            l = StartPoint'; % Make sure the start point will be erased
        end
	    % Get radius of each point from distance transform
	    radius = zeros(size(l, 1), 1);
	    parfor r = 1 : size(l, 1)
		    radius(r) = getradius(I, l(r, 1), l(r, 2), l(r, 3));
		end
	    radius(radius < 1) = 1;
		assert(size(l, 1) == size(radius, 1));

        [covermask, centremask] = binarysphere3d(size(T), l, radius);
	    % Remove the traced path from the timemap
        if cleanercheck & size(l, 1) > branchlen
            covermask = augmask(covermask, I, l, radius);
        end

        % covermask(StartPoint(1), StartPoint(2), StartPoint(3)) = 3; % Why? Double check if it is nessensary - SQ

        T(covermask) = -1;
        T(centremask) = -3;

	    % if cleanercheck
     %        T(wash==1) = -1;
     %    end

	    % Add l to the tree
        merged = true;
        dump = false;
        % if igonoreradiusflag
        %     radius = ones(size(radius));
        % end
	    if ~((dump) && dumpcheck) 
		    [tree, newtree, conf, unconnected] = addbranch2tree(tree, l, merged, connectrate, radius, I, branchlen, plot_value, somamerged);
            lconfidence = [lconfidence, conf];
		end

        B = B | covermask;

        percent = sum(B(:) & I(:)) / sum(I(:));
        % if plot
        %     axes(ax);
        % end
        printn = printn + 1;
        if printn > 1
            fprintf(1, repmat('\b',1,printcount));
            printcount = fprintf('Tracing percent: %f%%\n', percent*100);
        end
        if percent >= percentage
        	disp('Coverage reached end tracing...')
        	break;
        end
        counter = counter + 1;

    end

    meanconf = mean(lconfidence);

    if cleanercheck
        disp('Fixing topology')
        tree = fixtopology(tree);
    end 
    % tree = prunetree(tree, branchlen);

	if plot_value
		hold off
    end
    
    saveswc(tree, outfilename);