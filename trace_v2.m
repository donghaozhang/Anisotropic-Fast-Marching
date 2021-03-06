clear all; close all;
fprintf('Prepare for the original image : I binary image : bI\n');
% The following line is designed for zebrafish
% load('midzebraI.mat');
% mouseRGC
% load('miccaidata\experimentmouseRGC\mouseRGCresampled.mat');
% load('miccaidata\experimentjaneliafly\janeliaflypart2ex5resampled.mat');
% mid
% The first input variable I is inside op1resample.mat 
% load('op1resample.mat');
% outfilename = 'op1resample.swc';
load('zebraI.mat');
% load first5
% load('miccaidata\experimentfirst5\first5.mat')
% outfilename = 'janelia.swc';
% outfilename = 'op1resample.swc';
prefix_outfilename = 'miccaidata\experimentfirst5\first5';
% prefix_outfilename = 'miccaidata\experimentmouseRGC\mouseRGC';
% prefix_outfilename = 'miccaidata\experimentjaneliafly\janelia';
suffix_outfilename = '.swc';
% foreground_speed_list = [50 5 500 0.5];
foreground_speed_list = [30 40 50 60];
afmp_list = [0.93];
% midzebra threshold
% threshold = 70; 
% mouseRGC threshold
% threshold = 8;
% janeliafly part2 ex5
threshold = 40;
I_original = I;
I = I > threshold;
% oofilter;
% the following line load the binary image of mouse RGC
% load('miccaidata\experimentmouseRGC\mouseRGCresampledbI.mat');
% the following line load the binary image of janelia fly
% load('miccaidata\experimentjaneliafly\janeliaflybI.mat');
% save('mat\bI.mat','I');
% 
% i = 1;
% for i = 1 : numel(foreground_speed_list)  
for i = 1 : numel(afmp_list)  

    % The second input variable is plot
    plot_value = false;
    plot = false;

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
    connectrate = 1.2;

    % The ninth input variable is branchlen
    branchlen = 10;

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

    % The fifteenth input variable is ignoreradiusflag
    ignoreradiusflag = true;

    % The sixteenth input variable is prunetreeflag
    prunetreeflag = false;

    % The seventeen input variable is anisotropic fast marching 
    % afmp = 0.95;
    afmp = afmp_list(i);

    % The eighteenth input variable is to use speedimage to calculate diffusion matrix or not
    speedastensorflag = false;

    % The nineteenth input variable is to use hessianmatrix from oof at multiscale to calculate diffusion matrix or not
    oofhmflag = true;

    % The twentieth input variable control whether we will highlight the direction of first eigenvector 
    boostveconeflag = true; 

    % The twenty-first input variable control whether we will highlight the direction of first eigenvector 
    skeletonspeedflag = false;


    if plot
        axes(ax);
    end
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
	if plot
        axes(ax);
	end	
	disp('marching...');
    % Testing the relations of foreground speed coefficient 
    % foreground_speed_coeff = foreground_speed_list(i);
    foreground_speed_coeff = 60;    
    if (~atmapflag)
        T = msfm(SpeedImage, SourcePoint, false, false);
        fprintf('Multistencils fast marching is running.\n');
    else
        T = afm(I_original, threshold, foreground_speed_coeff, speedastensorflag, oofhmflag, afmp, boostveconeflag, skeletonspeedflag);
        fprintf('Anisotropic fast marching is running.\n');
    end
%     subplot(2,2,i)
    T_tmp = squeeze(max(T,[],3));
%     imagesc(permute(T_tmp, [2 1])); 
%     title(['Time map ' num2str(i)]);
    % save('T_rivulet.mat','T');
    szT = size(T);
    fprintf('the size of time map, x is : %d, y is : %d, z is : %d\n', szT(1), szT(2), szT(3));
    disp('Finish marching')

    if somagrowthcheck
        fprintf('Mark soma label on time-crossing map\n')
        T(soma.I==1) = -2;
    end

    if plot
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
    if plot
        axes(ax);
    end
    S = {};
    B = zeros(size(T));
    if somagrowthcheck
        B = B | (soma.I>0.5);
    end
    lconfidence = [];
    if plot
	    [x,y,z] = sphere;
	    plot3(x + SourcePoint(2), y + SourcePoint(1), z + SourcePoint(3), 'ro');
	end

    unconnectedBranches = {};
    printcount = 0;
    printn = 0;
    counter = 1;
    dumplist = [];
    branchlist = [];
    mergedlist = [];
    swclist = [];
    branchcounter = 0;
    hold on
    while(true)
        branchcounter = 1 + branchcounter;  
	    StartPoint = maxDistancePoint(T, I, true);

	    if plot
		    plot3(x + StartPoint(2), y + StartPoint(1), z + StartPoint(3), 'ro');
		end

	    if T(StartPoint(1), StartPoint(2), StartPoint(3)) == 0 || I(StartPoint(1), StartPoint(2), StartPoint(3)) == 0
	    	break;
	    end

	    [l, dump, merged, somamerged] = shortestpath2(T, grad, I, tree, StartPoint, SourcePoint, 1, 'rk4', gap);
        % scatter3(l(:,2), l(:,1), l(:,3));
        dump = false;
        merged = true;
        dumplist = [dump; dumplist];
        branchlist = [l; branchlist];
        if size(l, 1) == 0
            l = StartPoint'; % Make sure the start point will be erased
        end
        % scatter3(l(:,2), l(:,1), l(:,3), 'r');
	    % Get radius of each point from distance transform
	    radius = zeros(size(l, 1), 1);
	    parfor r = 1 : size(l, 1)
            radius(r) = getradius(I, l(r, 1), l(r, 2), l(r, 3));
            % radius(r) = getradiusoof(I, l(r, 1), l(r, 2), l(r, 3), eigvoof)
		    % radius(r) = getradiusfrangi(I, whatScale, l(r, 1), l(r, 2), l(r, 3));
		end
	    radius(radius < 1) = 1;
		% assert(size(l, 1) == size(radius, 1));

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
	    if ~((dump) && dumpcheck)
            % scatter3(l(:,2), l(:,1), l(:,3), 'b');
            swclist = [swclist;branchcounter];
		    [tree, newtree, conf, unconnected] = addbranch2tree(tree, l, merged, connectrate, radius, I, branchlen, plot, somamerged);
            lconfidence = [lconfidence, conf];
		end

        B = B | covermask;

        percent = sum(B(:) & I(:)) / sum(I(:));
        if plot
            axes(ax);
        end
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
    if prunetreeflag 
        tree = prunetree_afm(tree, branchlen, plot_value);
    end

	if plot
		hold off
    end
    

    if ignoreradiusflag
        radius_vec = ones(size(tree(:,6)));
        tree(:,6) = radius_vec;
    end
    % var9_1 means input ninth variable is 1
    curtime = clock;
    timelist = fix(curtime);
    timestring = [];
    for i = 1 : numel(timelist) 
        curstring = num2str(timelist(i));
        timestring = [timestring curstring];
    end
    outfilename = [prefix_outfilename timestring suffix_outfilename];
    rivuletpara.plot_value = plot_value;
    rivuletpara.percentage = percentage;
    rivuletpara.rewire = rewire;
    rivuletpara.gap = gap;
    rivuletpara.ax_value = ax_value;
    rivuletpara.dumpcheck = dumpcheck;
    rivuletpara.connectrate = connectrate;
    rivuletpara.branchlen = branchlen;
    rivuletpara.somagrowthcheck = somagrowthcheck;

    rivuletpara.cleanercheck = cleanercheck;
    rivuletpara.dtimageflag = dtimageflag;
    rivuletpara.atmapflag = atmapflag;
    rivuletpara.ignoreradiusflag = ignoreradiusflag;
    rivuletpara.prunetreeflag = prunetreeflag;
    rivuletpara.afmp = afmp;
    rivuletpara.speedastensorflag = speedastensorflag;
    rivuletpara.oofhmflag = oofhmflag;
    rivuletpara.boostveconeflag = boostveconeflag;
    rivuletpara.skeletonspeedflag = skeletonspeedflag;
    % showbibox(I);
    showswc(tree);
    % compareradiusoof;
    saveswc(tree, outfilename);
    savepara(rivuletpara, outfilename);
%     hold on
%     scatter3(branchlist(:,2), branchlist(:,1), branchlist(:,3), 'b');
%     hold off
end