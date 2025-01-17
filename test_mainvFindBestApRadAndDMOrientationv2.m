% EFC with fiber, code for lab demonstration
% Notes:
%   - Regularization parameter: which one to chose? This choice affects how
%   fast the dark hole is digged, and the damping of the actuators pulse
%   - Normalization of the model WF: the propagated model used to build the
%   G matrix and to do the sensing of the actual WF, has to be normalized
%   in the same way as the actual WF.
clear all;
close all;
addpath(genpath('utils'),genpath('export_scripts'));

% use_fiber = true;
% normal_EFC = false;
EFCSMF = true;
debug = true;
regularizationMarx = false;
broadband = true;

if EFCSMF
    EFCmethod = 'EFCSMF';
else
    EFCmethod = 'RegEFC';
end
if ~broadband
    source = 'laserSource';
else
    source = 'broadband';
end
label = ['_',EFCmethod,'_',source,'_1config_Aug31'];
outDir = ['output',filesep,'EFC_wFiber_LabDemonstration',label,filesep];
mkdir(outDir);

load('output\calibrateDM_Aug01'); % actxcDM, angDm vs pix on camera info

% Initialize all devices
hcstt_Initialize(true);

% load('benchModelPixelPitchMatching_scaleR_apRad_May7')
N = 2^10;

[X,Y] = meshgrid(-N/2:N/2-1); 
xvals = X(1,:);yvals = Y(:,1);
[THETA,RHO] = cart2pol(X,Y);
if broadband
    tint0 = 15;
else
    tint0 = 7;
end
tint = tint0;


lambda0 = 635e-9;
numOfWavelengths = 1; % monochromatic, use 1
percentBW = 10; % percent bandwidth=(Delta lambda)/lambda*100
BW = percentBW/100; % bandwidth 
if(numOfWavelengths > 1)
    lam_fracs = linspace(1-BW/2,1+BW/2,numOfWavelengths);
else
    lam_fracs = 1;
end
lam_arr = lambda0*lam_fracs;
Nact = 12;  % Number of DM actuators, Nact^2

% These are parameters used in the propagation routines  
info.useGPU = false;
info.RHO = RHO;
info.THETA = THETA;
info.N = N;
info.lambda0 = lambda0;
info.lam_arr = lam_arr;
info.numOfWavelengths = numOfWavelengths;
info.useApodizer = false;
info.useGPU = false; 
info.FPM = exp(1i*4*THETA);
info.outDir = outDir;
info.xvals = xvals;
info.yvals = yvals;
% info.use_fiber = use_fiber;
% info.normal_EFC = normal_EFC;
info.EFCSMF = EFCSMF;
info.tint = tint;
info.LPM = ones(N,N);
info.Nact = Nact;

% Total Power to normilize model Gu and intensity from the fiber. Need of
% normalization factor
if ~broadband
    totalPowerEFCSMF = 2.2331e-06;
else
    totalPowerEFCSMF = 5.9992e-06;
end
normPowerEFCSMF = totalPowerEFCSMF/3.8185e10;
peakIntEFCSMF = totalPowerEFCSMF;

if ~EFCSMF
    if ~broadband
        load('BenchModelNormalization_laserSource_0829')
    else
        load('BenchModelNormalization_broadband_0830')
    end
    normPowerRegEFC = normPower_normalization*tint/tint_normalization;%0.00055;%
    % normPowerRegEFC = 9e-5;
    peakIntRegEFC = peakInt_normalization*tint/tint_normalization;
    info.normPowerRegEFC = normPowerRegEFC;
end

if ~broadband
    load('calibrationMMFPixGauss_broadband_Aug30')
else
    load('calibrationMMFPixGauss_laserSource_Aug30')
end
totalPowerMMF0 = totalPowerMMF_calibration*tint/tint_MMF_calibration;
totalPowerMMF = totalPowerMMF0;
totalPowerPixGauss0 = totalPowerPixGauss_calibration*tint/tint_MMF_calibration;
totalPowerPixGauss = totalPowerPixGauss0;
if EFCSMF
    info.p2v_dm_sensing = 12;
    info.normPower = normPowerEFCSMF;
else
    info.p2v_dm_sensing = 4;
    info.normPower = normPowerRegEFC;
end

% Update shape of DM with SN result
hcstt_NewFlatForDM('ImageSharpeningModel_0801_flatv2');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%55
% hcstt_NewFlatForDM('NewFlat_SpeckleOnFiber_May10');
% hcstt_NewFlatForDM('output\NewFlat_testPReviousEFCRun');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%55

% Take background image
take_background = true;
Ncam = 400;
if(take_background)
    prompt = 'Take out light. Continue? ';
    x = input( prompt );
    im_cam = zeros(Ncam,Ncam);
    for II=1:15
        im_camII = hcstt_TakeCamImage(true,false,tint);
        im_cam = im_cam + im_camII/15;
        pause(0.1)
    end
    backgroundCam = im_cam;
    backgroundSMF = hcstt_GetIntensityFIU(zeros(Nact,Nact),15,0);
    prompt = 'Put back light on. Continue? ';
    x = input( prompt );
else
    backgroundCam = zeros(Ncam,Ncam);
    backgroundSMF = 0;
end
info.backgroundCam = backgroundCam;
info.backgroundSMF = backgroundSMF;

% Find Center of camera image
im_cam = zeros(Ncam,Ncam);
tint_findCenter = 0.5;
for II=1:25
    im_camII = hcstt_TakeCamImage(true,false,tint_findCenter);
    im_cam = im_cam + im_camII/25;
    pause(0.1)
end
im_camaux = im_cam;
im_camaux(190:210,190:210) = im_camaux(190:210,190:210)*1000;
[ma,ind_ma] = max(im_camaux(:));
[x_cent_cam,y_cent_cam] = ind2sub(size(im_camaux),ind_ma);
if max(im_camII(:))>240
    disp('Find Center image saturated')
    hcstt_DisconnectDevices
    return
end
info.x_cent_cam = x_cent_cam;
info.y_cent_cam = y_cent_cam;

%Find position of fiber
x_fib_est = 2.5;
% [actxc_fib,ang_fib] = hcstt_FindPosiotionFiberv4(x_fib_est,0,info);
actxc_fib = 2.5;
ang_fib = 0;
info.actxc_fib = actxc_fib;
info.ang_fib = ang_fib;
%Calculate position in pixels
if actxc_fib>max(actxcDM_arr) 
    r_fib_pix = interp1(actxcDM_arr,distPix_meas,actxc_fib,'linear','extrap');
elseif actxc_fib<min(actxcDM_arr)
    disp('Fiber too far away from star!')
    return;
else
    r_fib_pix = interp1(actxcDM_arr,distPix_meas,actxc_fib);
end
x_fib_pix = -r_fib_pix*cos(ang_fib);
y_fib_pix = -r_fib_pix*sin(ang_fib);
info.x_fib_pix = x_fib_pix;
info.y_fib_pix = 0;
% x_fib=2.5;
% y_fib=0;
% info.x_fib = x_fib;
% info.y_fib = y_fib;

% Save image of flat DM without SN
im_cam = hcstt_TakeCamImage(true,false,tint)-backgroundCam;
sz_imcam = size(im_cam);
info.sz_imcam = sz_imcam;
hcstt_test_plotCamImage(im_cam(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20), 'Camera Image - Flat DM',[outDir,'CamImage_flatDM'], [41,41] );

counttot = 0;

apRad = 142;%apRad_arr(apRII);
lambdaOverD = N/apRad/2; % lambda/D (samples) 
info.apRad = apRad;
info.lambdaOverD = lambdaOverD;

info.LPM = exp(-(RHO/(0.85*apRad)).^1000);

fiberDiam = 2*0.71; % Fiber diam. (lambda_0/D)
fiberDiam_pix = (fiberDiam*lambdaOverD);

% Compute Q
% wfin_noerrors = complex(ones(N, N), zeros(N, N)) ;
% wfin_noerrors(RHO > apRad) = 0;
% wf2 = prescription_DM1toImage_compact_vFiberCoupling_broadband( wfin_noerrors, surf_DM10, true, info);
% wf2 = wf2 * sqrt(info.normPower);
% info.normalize = false;
% im_mod = hcstt_TakeModelImage(zeros(Nact,Nact),false,info);
wf1 = exp( -(RHO/(apRad)).^100 );
wf2 = prescription_DM1toImage_compact_vFiberCoupling_broadband( wf1, zeros(N,N), false, info);
% wf2_crop = wf2(N/2-sidepix+1:N/2+sidepix+1,N/2-sidepix+1:N/2+sidepix+1);
% totalPower = sum(abs(wf2_crop(:)).^2);

[Xcam,Ycam] = meshgrid(-y_cent_cam+1:Ncam-y_cent_cam,-x_cent_cam+1:Ncam-x_cent_cam); 
[THETAcam, RHOcam] = cart2pol(Xcam - x_fib_pix,Ycam- y_fib_pix);
% q_pix = 1;
% info.q_pix = q_pix;
% Q = zeros(Ncam,Ncam);
% Q = and(Xcam >= (x_fib_pix-q_pix ), Xcam <=  (x_fib_pix+q_pix ));
% Q = and(Q, Ycam >= -(q_pix) );
% Q = and(Q, Ycam <= (q_pix) );
% [Q,totalPowerMMF] = hcstt_GenerateDHMask(wf2,Xcam,Ycam,info);
Q = exp(-(RHOcam/(fiberDiam_pix/2)).^100);
info.Q = Q;
% IWA_pix = (x_fib_pix-q_pix );
% OWA_pix = (x_fib_pix+q_pix );
% angleDH = 0;%pi/12;
% Q4G = zeros(Ncam,Ncam);
[Xcam4G,Ycam4G] = meshgrid(-Ncam/2-1:Ncam/2-2); 
% Q4G = zeros(Ncam,Ncam);
% Q4G = and(Xcam4G >= (x_fib_pix-q_pix ), Xcam4G <=  (x_fib_pix+q_pix ));
% Q4G = and(Q4G, Ycam4G >= -(q_pix) );
% Q4G = and(Q4G, Ycam4G <= (q_pix) ); % 60deg keystone about x-axis
% Q4G = hcstt_GenerateDHMask(wf2,Xcam4G,Ycam4G,info);
[THETA4G_fib,RHO4G_fib] = cart2pol(Xcam4G - x_fib_pix ,Ycam4G - y_fib_pix);
Q4G = exp(-(RHO4G_fib/(fiberDiam_pix/2)).^100);
num_Q = numel(find(Q));
info.num_Q = num_Q;
info.Q4G = Q4G;

% Model of the fiber mode shape
[THETA_fib,RHO_fib] = cart2pol(X - x_fib_pix ,Y - y_fib_pix);
fibermode0 = sqrt(2/(pi*(fiberDiam_pix/2)^2))* ...
        exp(-(RHO_fib/(fiberDiam_pix/2)).^2);
fibermodeCam0 = sqrt(2/(pi*(fiberDiam_pix/2)^2))* ...
        exp(-(RHOcam/(fiberDiam_pix/2)).^2);
info.fibermode0 = fibermode0;

info.fiberDiam = fiberDiam;

for posII=1:3

    tint = tint0;
    totalPowerMMF = totalPowerMMF0;
    totalPowerPixGauss = totalPowerPixGauss0;
    
    [posDM_x,posDM_y,ac_spac] = hcstt_PositionDMActuatorsvFindBestDMOrientation(N,apRad,posII);
    info.posDM_x = posDM_x;
    info.posDM_y = posDM_y;
    info.ac_spac = ac_spac;

    % Load the DM influence functions
    % ac_spac = round(2*apRad/Nact);
    infl = loadInfluenceFunction( 'influence_dm5v2.fits', ac_spac ); % Influence function. Need of a model for actual DM
    info.infl = infl;

    % Initialize DMs, etc. 
    DM1_strokes = zeros(N); % Intialize the DM strokes to flat
    us = zeros(Nact^2,1); % Initialize the fractional stroke changes to zero
    us_total = zeros(Nact^2,1); % Initialize the fractional stroke changes to zero
    poke_amp = 1e-9; % Initialize the poke amplitude

    if regularizationMarx
        maxits = 35; % maximum number of EFC iterations allowed
    else
        maxits = 15;
    end
    Gcount = 0; % counter for number of times G matrix was used
    Gcountmin = 6; % Minimum number of times to use a G matrix
    curr_coupl_SMF = 1;
    curr_int = 1e9;
    recalc_G = true; % Initialize the flag to re-calculate the G matrix
    regularizationMarxOn = false;
    % regvals = logspace(-6,-1,6); % Range of regularization parameters to test
    regval = nan; % Initial regularization value
    int_in_DH = []; % Array to keep track of dark hole irradiance 
    int_est_in_DH = []; % Array to keep track of dark hole irradiance 
    coupl_SMF_in_DH = [];
    coupl_MMF_in_DH = [];
    tint_arr = [];
    totalPowerMMF_arr = [];
    totalPowerPixGauss_arr = [];
    coupl_pixGauss_in_DH = []';
    % Run EFC iterations 
    for k = 1:maxits
        counttot = counttot+1;

        fprintf('Iteration: %d ',k);
        fprintf('\n')

        % Update actuator height with the LMS solution, us
        us_total = us_total + us;

        % Build DM surface from stroke amplitudes 
        count = 0; 
        for ix = 1:Nact
            xpos = round(posDM_x(ix));%round(N/2+1+(ix-Nact/2-0.5)*ac_spac);
            for iy = 1:Nact
                count = count + 1;
                ypos = round(posDM_y(iy));%round(N/2+1+(iy-Nact/2-0.5)*ac_spac);
                DM1_strokes(xpos,ypos) = us(count)*poke_amp + DM1_strokes(xpos,ypos);
            end
        end
        surf_DM10 = conv2(DM1_strokes,infl,'same');

        %Make of plot of the current DM surface 
        figure(100);
        imagesc(xvals/apRad,yvals/apRad,surf_DM10*1e9);
        colormap(gray(256));hcb=colorbar;
        %caxis([0 10e-9]);
        axis image;%axis off;% 
        axis([-1.1 1.1 -1.1 1.1]);set(gca,'XTick',-1:0.5:1,'YTick',-1:0.5:1);
        %text(-1.05,0.98,'{\bf(c)}','FontSize',12,'Color','w')
        hx = xlabel('{\itx} / {\itR}');
        hy = ylabel('{\ity} / {\itR}');
        title('DM1 surface height (nm)');
        set(gca,'FontSize', 10,...
                        'TickDir','out',...
                        'TickLength',[.02 .02]);
%         set(gca,'YDir','normal');
%         set(fig0,'units', 'inches', 'Position', [0 0 5 5])
%             if debug
%                 export_fig([info.outDir,'DM1surf_',num2str(k),'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png']);
%             else
            if k == maxits
                export_fig([info.outDir,'DM1surf_final_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png']);
            end
%             end
%         close(fig0);    

        % Simualte WF in image plane with current DM shape, this is needed for the WF sensing 
%             if k>5
%                 wf2_current = prescription_DM1toImage_compact_vFiberCoupling_broadband( wfin_noerrors, surf_DM10, true, info);
%                 wf2_current = wf2_current * sqrt(normPower);
%             end
        if k==1
            wf2_current = prescription_DM1toImage_compact_vFiberCoupling_broadband( wf1, surf_DM10, true, info);
            wf2_current = wf2_current * sqrt(info.normPower);
            immod_flat = abs(wf2_current).^2;
            figure(5)
            immod_flat = immod_flat(N/2-sz_imcam(1)/2:N/2+sz_imcam(1)/2-1,N/2-sz_imcam(2)/2:N/2+sz_imcam(2)/2-1);
%                 immod_flat(Q4G) = max(immod_flat(:));
            imagesc(immod_flat(Ncam/2-20:Ncam/2+20,Ncam/2-20:Ncam/2+20))
            axis image
            title('Im Cam flat DM')
        end
%         end


        % Perform WF sensing
        if EFCSMF
            Eab =  EFSensing_EFCwFiber_labTestv2(wf2_current,us_total*poke_amp,info);
            Eabreg = [Eab(1);Eab(2); zeros(Nact^2,1)];    
%                 if debug
%                     % Check how the sesnsing looks like with flat DM at each
%                     % iteration
%                     wf2_flatDM = prescription_DM1toImage_compact_vFiberCoupling_broadband( wfin_noerrors, surf_DM10*0.0, true, info);
%                     wf2_flatDM = wf2_flatDM * sqrt(normPower);
%                     Eab_check =  EFSensing_EFCwFiber_labTest(wf2_flatDM,us_total*poke_amp*0.0,info);
%                     Eab1_fib_check_arr(counttot) = Eab_check(1);
%                     Eab2_fib_check_arr(counttot) = Eab_check(2);
%                     elapsedTime_arr(counttot) = toc;
%                 end
        else
            Eab =  EFSensing_RegularEFC_labTest(wf2_current,us_total*poke_amp,info);
            Eabreg = [Eab(1,:)';Eab(2,:)'; zeros(Nact^2,1)];
        end
        %

        % Check progress
        imaux = abs(wf2_current).^2;
        imaux = imaux(N/2-sz_imcam(1)/2:N/2+sz_imcam(1)/2-1,N/2-sz_imcam(2)/2:N/2+sz_imcam(2)/2-1);
        figure(201)
        imagesc(imaux(Ncam/2-20:Ncam/2+20,Ncam/2-20:Ncam/2+20))
        title('Model Image Current Iteration')
        axis image
        drawnow;

        figure(202)
        hcstt_UpdateMultiDM(+us_total)
        im_cam = hcstt_TakeCamImage(true,false,tint)-backgroundCam;
        imagesc(im_cam(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20))
        axis image
        title('Cam Image Current Iteration')
        colorbar
        drawnow;

        prev_coupl_SMF = curr_coupl_SMF;
        curr_coupl_SMF = hcstt_GetIntensityFIU(+(us_total)*poke_amp/1e-9,10,backgroundSMF );%sum(abs(Eab).^2/totalPower)/numel(lam_fracs);
        coupl_SMF_in_DH = [coupl_SMF_in_DH, curr_coupl_SMF];
        int_in_DH = [int_in_DH, mean(im_cam(find(Q)))];
        coupl_MMF_in_DH = [coupl_MMF_in_DH, sum(sum(im_cam.*Q))];
        coupl_pixGauss_in_DH = [coupl_pixGauss_in_DH, sum(sum(im_cam.*fibermodeCam0))];
        tint_arr = [tint_arr,tint];
        totalPowerMMF_arr = [totalPowerMMF_arr,totalPowerMMF];
        totalPowerPixGauss_arr = [totalPowerPixGauss_arr,totalPowerPixGauss];
        
        figure(203);
        plot(1:k,log10(coupl_MMF_in_DH./totalPowerMMF_arr))
        hold on
        plot(1:k,log10(coupl_SMF_in_DH/peakIntEFCSMF))
        hold off
        xlabel('Iteration')
        ylabel('Raw Contrast (Log Scale)')
        if EFCSMF
            title(['EFC -  (Suppression of ',num2str(coupl_SMF_in_DH(1)/coupl_SMF_in_DH(k)),')'])
        else
            title(['EFC -  (Suppression of ',num2str(int_in_DH(1)/int_in_DH(k)),')'])
        end
        legend(['Pix box'],'SMF');

        if EFCSMF
            curr_int_est =  sum(sum(abs(Eab).^2))/numel(lam_fracs);

            prev_int = prev_coupl_SMF;
            curr_int = curr_coupl_SMF;
        else
            curr_int_est = sum(sum(abs(Eab).^2))/numel(Eab(1,:))/numel(lam_fracs);
            prev_int = curr_int;
            curr_int = mean(im_cam(find(Q)));

            % Plot estimated intensity with measured intensity
            figure(222)
            int = abs(Eab(1,:)).^2+abs(Eab(2,:)).^2;
            plot(1:num_Q,int)
            hold on
            plot(1:num_Q,im_cam(find(Q)))
            hold off
            legend('Estimated','Camera')
            title('Estimated Int vs Measured Int')

            im_camaux = im_cam;
            im_camaux(find(Q)) = nan;
            figure(223)
            imagesc(im_camaux(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20))
            axis image
        end
        int_est_in_DH = [int_est_in_DH, curr_int_est];

        fprintf([' Mean MeasIntensity in DH: ', num2str(curr_int)])
        fprintf('\n')
        fprintf([' Mean EstIntensity in DH: ', num2str(curr_int_est)])
        fprintf('\n')

        % Determine whether to continue and/or calculate a new G matrix
%             if(prev_int<curr_int)
    %         return;
        if(Gcount > Gcountmin)
            recalc_G = true;
        end

        % Sets the new DM poke amplitude based on current dark hole irr. 
%             poke_amp = 1e-9;%sqrt(curr_irr)*lambda0;

        % calculate the G matrix, if needed
        if(recalc_G)
            Gcount = 0;
            disp('Calculating the G matrix for EFC.')
%                 if k==1 && posII==1
%                     load('output\G_it1_Aug31.mat')
%                 else
            if ~EFCSMF
                G = calculateGmatrix_vFiberCouplingOneFibxel_broadband( wf1, surf_DM10, Q4G, Nact, ac_spac, poke_amp, infl, lambda0, N , info);
            else
                G = calculateGmatrix_vFiberCouplingOneFibxel_broadband( wf1, surf_DM10, [], Nact, ac_spac, poke_amp, infl, lambda0, N , info);
            end
            save(['output\G_pos',num2str(posII),'.mat'],'G');
%                 end
            recalc_G = false;
        end
        Gcount = Gcount + 1; % Count the times the current G matrix has bee used

        Gsplit = [real(G);imag(G)]; % Splits the G-matrix into real and imaginary parts 

        % Regalarization value, to be updated each iteration?
        if regularizationMarx && k==11
            regval = 1e-6;
            gainval = 1;  
            regularizationMarxOn = true;
        elseif regularizationMarx && k==16
            regval = 1e-4;
            gainval = 1;  
            regularizationMarxOn = true;
        elseif regularizationMarx && k==21
            regval = 1e-8;
            gainval = 1;  
            regularizationMarxOn = true;
        elseif regularizationMarx && k==25
            regularizationMarxOn = false;
        end
        if ~regularizationMarxOn
            numreg = 7;
            numgain = 5;
            regval_arr = logspace(-8,-1,numreg);
            gain_arr = linspace(0.1,4,numgain);
            curr_reg_arr = zeros(1,numreg*numgain) + nan;
            countreg = 1;
            for III=1:numgain
                for II=1:numreg
                %     regval = 0.1; % To be determined
                    regval = regval_arr(II);
                    %

                    Greg = [Gsplit;regval*eye(Nact^2)]; 

                    % Compute the  new actuator heights
                    usII = -1*pinv(Greg)*Eabreg; % 
                    usII = usII*gain_arr(III);
                    %
                    if max(usII)<20
    %                     us_total2 = vec2mat(usII+us_total,12);
    %                     us_total2 = us_total2';

                        if ~EFCSMF
                            hcstt_UpdateMultiDM(+(us_total+usII)*poke_amp/1e-9)
                            im_camreg = hcstt_TakeCamImage(true,false,tint)-backgroundCam;
                            curr_reg_arr(countreg) = mean(im_camreg(find(Q)));
                        else
                            curr_reg_arr(countreg) = hcstt_GetIntensityFIU(+(us_total+usII)*poke_amp/1e-9,5 ,backgroundSMF);
                        end
                    end
                    countreg = countreg + 1;
                end
            end
            [mi,ind_min] = min(curr_reg_arr);
            [ind_minreg,ind_mingain] = ind2sub([numreg,numgain],ind_min);
            regval = regval_arr(ind_minreg);
            gainval = gain_arr(ind_mingain);
        end
        regvalfin_arr(k) = regval;
        gainvalfin_arr(k) = gainval;

        save([info.outDir,'DMshapes.mat'],'surf_DM10');
        save([info.outDir,'DM1_strokes.mat'],'DM1_strokes');

        Greg = [Gsplit;regval*eye(Nact^2)]; % Final G matrix to be used

        % Compute the  new actuator heights
        us = -1*pinv(Greg)*Eabreg; %  
        us = us*gainval;

        if debug
            if k==1
                Greg = [Gsplit;zeros(Nact^2)];
                us0 = -1*pinv(Greg)*Eabreg; %
                save([info.outDir,'us0_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.mat'],'us0');
            end
        end
        %

        %Check if everything is OK
        us_max = max(us*poke_amp*1e9);
        us_max_arr(counttot) = us_max;
        if EFCSMF
            curr_suppression = coupl_SMF_in_DH(1)/coupl_SMF_in_DH(k);
        else
            curr_suppression = int_in_DH(1)/int_in_DH(k);
        end
        fprintf([' Max us: ', num2str(us_max),'nm'])
        fprintf('\n')
        fprintf([' Regularization value: ', num2str(regval)])
        fprintf([' Gain value: ', num2str(gainval)])
        fprintf('\n')
        fprintf([' Current Suppression ', num2str(curr_suppression)])
        fprintf('\n')
%         if k==5 && curr_suppression<50
%             break
%         end
        if min(im_cam(find(Q)))<3
            disp('  Changing exposure time')
        	tint = tint*2;
            info.tint = tint;
            totalPowerMMF = totalPowerMMF_calibration*tint/tint_MMF_calibration;
            totalPowerPixGauss = totalPowerPixGauss_calibration*tint/tint_MMF_calibration;
        end
        

    end
%% update one last time with new solution

    fprintf('Update with last solution');
    k = k+1;
    % Update actuator height with the LMS solution, us
    us_total = us_total + us;

    % Build DM surface from stroke amplitudes 
    count = 0; 
    for ix = 1:Nact
        xpos = round(posDM_x(ix));%round(N/2+1+(ix-Nact/2-0.5)*ac_spac);
        for iy = 1:Nact
            count = count + 1;
            ypos = round(posDM_y(iy));%round(N/2+1+(iy-Nact/2-0.5)*ac_spac);
            DM1_strokes(xpos,ypos) = us(count)*poke_amp + DM1_strokes(xpos,ypos);
        end
    end
    surf_DM10 = conv2(DM1_strokes,infl,'same');

    %Make of plot of the current DM surface 
    figure(100);
    imagesc(xvals/apRad,yvals/apRad,surf_DM10*1e9);
    colormap(gray(256));hcb=colorbar;
    %caxis([0 10e-9]);
    axis image;%axis off;% 
    axis([-1.1 1.1 -1.1 1.1]);set(gca,'XTick',-1:0.5:1,'YTick',-1:0.5:1);
    %text(-1.05,0.98,'{\bf(c)}','FontSize',12,'Color','w')
    hx = xlabel('{\itx} / {\itR}');
    hy = ylabel('{\ity} / {\itR}');
    title('DM1 surface height (nm)');
    set(gca,'FontSize', 10,...
                    'TickDir','out',...
                    'TickLength',[.02 .02]);
%         set(gca,'YDir','normal');
%         set(fig0,'units', 'inches', 'Position', [0 0 5 5])
    if debug
        export_fig([info.outDir,'DM1surf_',num2str(k),'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png']);
    end

    % Simualte WF in image plane with current DM shape, this is needed for the WF sensing
    wf2_current = prescription_DM1toImage_compact_vFiberCoupling_broadband( wf1, surf_DM10, true, info);
    wf2_current = wf2_current * sqrt(info.normPower);

    % Perform WF sensing
    if ~EFCSMF
        Eab =  EFSensing_RegularEFC_labTest(wf2_current,us_total*poke_amp,info);
        Eabreg = [Eab(1,:)';Eab(2,:)'; zeros(Nact^2,1)];
    else
        Eab =  EFSensing_EFCwFiber_labTestv2(wf2_current,us_total*poke_amp,info);
        Eabreg = [Eab(1);Eab(2); zeros(Nact^2,1)]; 
    end
    %

    % Check progress
    figure(200)
    hcstt_UpdateMultiDM(+us_total)
    im_cam = hcstt_TakeCamImage(true,false,tint)-backgroundCam;
    imagesc(im_cam(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20))
    axis image
    colorbar
    drawnow;
    int_in_DH = [int_in_DH, mean(im_cam(find(Q)))];
    coupl_MMF_in_DH = [coupl_MMF_in_DH, sum(sum(im_cam.*Q))];
    coupl_pixGauss_in_DH = [coupl_pixGauss_in_DH, sum(sum(im_cam.*fibermodeCam0))];
    prev_coupl_SMF = curr_coupl_SMF;
    curr_coupl_SMF = hcstt_GetIntensityFIU(+(us_total)*poke_amp/1e-9,10,backgroundSMF );%sum(abs(Eab).^2/totalPower)/numel(lam_fracs);
    coupl_SMF_in_DH = [coupl_SMF_in_DH, curr_coupl_SMF];
    tint_arr = [tint_arr,tint];
    totalPowerMMF_arr = [totalPowerMMF_arr,totalPowerMMF];
    totalPowerPixGauss_arr = [totalPowerPixGauss_arr,totalPowerPixGauss_calibration*tint/tint_MMF_calibration];

    if EFCSMF
        curr_int_est =  sum(sum(abs(Eab).^2))/numel(lam_fracs);
        prev_int = prev_coupl_SMF;
        curr_int = curr_coupl_SMF;
    else
        curr_int_est = sum(sum(abs(Eab).^2))/numel(Eab(1,:))/numel(lam_fracs);
        prev_int = curr_int;
        curr_int = mean(im_cam(find(Q)));
    end    
    int_est_in_DH = [int_est_in_DH, curr_int_est];

    fprintf(['Mean MeasIntensity in DH: ', num2str(curr_int)])
    fprintf([' Mean EstIntensity in DH: ', num2str(curr_int_est)])


%         close(fig0);    
%% Save data from this EFC run

    fig0 = figure(301);
%     plot(1:k,log10(int_in_DH/peakIntRegEFC))
    if EFCSMF
        plot(1:k,log10(coupl_MMF_in_DH./totalPowerMMF_arr))
    else
        plot(1:k,log10(int_in_DH/peakIntRegEFC))
    end
    hold on
    plot(1:k,log10(coupl_SMF_in_DH/peakIntEFCSMF))
    plot(1:k,log10(coupl_pixGauss_in_DH./totalPowerPixGauss_arr))
    hold off
    xlabel('Iteration')
    ylabel('Raw Contrast (Log Scale)')
    if EFCSMF
        title(['EFCSMF -  (Suppression of ',num2str(coupl_SMF_in_DH(1)/coupl_SMF_in_DH(k)),')'])
    else
        title(['Regular EFC -  (Suppression of ',num2str(int_in_DH(1)/int_in_DH(k)),')'])
    end
%     pixbox = q_pix*2+1;
    legend(['Pix aperture'],'SMF','Gaussian filtering on intensity over pixels');
    export_fig([outDir,'MeanInt_vs_it',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png'],'-r300');
    close(fig0);

    fig0 = figure(3);
    if EFCSMF
        plot(1:k,log10(int_est_in_DH/peakIntEFCSMF))
    else
        plot(1:k,log10(int_est_in_DH/peakIntRegEFC))
    end
    xlabel('Iteration')
    ylabel('Mean EST Intensity (Log Scale)')
    title(['EFC - Mean EST Intensity vs it'])
%     ylim([0 1e-3])
    % legend('Coupling SMF','Coupling MMF');
    export_fig([outDir,'MeanESTInt_vs_it',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png'],'-r300');
    close(fig0);

    if ~EFCSMF
        fig0 = figure(4);
        imagesc(im_cam(Ncam/2-20:Ncam/2+20,Ncam/2-20:Ncam/2+20))
        axis image
        title(['Simulated image to see where Q falls DMconfig',num2str(posII),' apRad',num2str(apRad),])
        export_fig([outDir,'SimulatedImageWhereQFalls',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png'],'-r300');
        close(fig0);
    end

    hcstt_UpdateMultiDM(+us_total)
    figure(6);
    im_cam = hcstt_TakeCamImage(true,false,tint)-backgroundCam;
    imagesc(im_cam(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20))
    axis image
    title(['Final Image DMconfig',num2str(posII),'apRad',num2str(apRad),])
    colorbar
    export_fig([outDir,'CamImageFinalImage',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png'],'-r300');
    im_cam_crop = im_cam(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20);
    figure(7);
    im_camtintdiv2 = hcstt_TakeCamImage(true,false,tint/2)-backgroundCam;
    imagesc(im_camtintdiv2(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20))
    axis image
    title(['Final Image DMconfig',num2str(posII),'apRad',num2str(apRad),])
    colorbar
    export_fig([outDir,'CamImageFinalImage',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png'],'-r300');
    im_camtintdiv2_crop = im_camtintdiv2(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20);
    figure(8);
    im_camtintdiv3 = hcstt_TakeCamImage(true,false,tint/3)-backgroundCam;
    imagesc(im_camtintdiv2(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20))
    axis image
    title(['Final Image DMconfig',num2str(posII),'apRad',num2str(apRad),])
    colorbar
    export_fig([outDir,'CamImageFinalImage',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.png'],'-r300');
    im_camtintdiv3_crop = im_camtintdiv3(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20);

    if ~EFCSMF
    save([info.outDir,'data_intvsit_dmshapes_',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.mat'],...
        'us_total','im_cam_crop','int_in_DH','coupl_SMF_in_DH','coupl_MMF_in_DH',...
        'peakIntRegEFC','peakIntEFCSMF','totalPowerPixGauss_arr','coupl_pixGauss_in_DH',...
        'totalPowerMMF_arr','int_est_in_DH','regvalfin_arr','gainvalfin_arr',...
        'im_cam','im_camtintdiv2','im_camtintdiv2_crop','im_camtintdiv3','im_camtintdiv3_crop',...
        'actxc_fib','ang_fib','Q');
    else
    save([info.outDir,'data_intvsit_dmshapes_',label,'_DMconfig',num2str(posII),'_apRad',num2str(apRad),'.mat'],...
        'us_total','im_cam_crop','int_in_DH','coupl_SMF_in_DH','coupl_MMF_in_DH',...
        'peakIntEFCSMF','totalPowerPixGauss_arr','coupl_pixGauss_in_DH',...
        'totalPowerMMF_arr','int_est_in_DH','regvalfin_arr','gainvalfin_arr',...
        'im_cam','im_camtintdiv2','im_camtintdiv2_crop','im_camtintdiv3','im_camtintdiv3_crop',...
        'actxc_fib','ang_fib','Q');
    end
end
%     hcstt_test_plotCamImage(im_cam(x_cent_cam-20:x_cent_cam+20,y_cent_cam-20:y_cent_cam+20), [outDir,'CamImage_final','_DMconfig',num2str(posII)], [41,41] );

hcstt_DisconnectDevices();

