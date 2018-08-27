function [ x_hat ] =  EFSensing_EFCwFiber_labTestv2(wf0,us_total,info)
%Performs the Electric Field extraction using the intensities from a fiber.
%Returns the overlap integral of the EF through the fiber

%     us_total = vec2mat(us_total,12);
%     us_total = us_total';

N = info.N;

apRad = info.apRad;
[X,Y] = meshgrid(-N/2:N/2-1); 
xvals = X(1,:);yvals = Y(:,1);
[THETA,RHO] = cart2pol(X,Y);
lambdaOverD = info.lambdaOverD; 

fiberDiam = info.fiberDiam; % Fiber diam. (lambda_0/D)

rng(3);
% error_map = fitsread('surfErrorMap_OX5.fits'); %nm

wfin_noerrors = complex(ones(N, N), zeros(N, N)) ;
wfin_noerrors(RHO > apRad) = 0;


% x_fib = info.x_fib; % Position of the fiber on the image plane. (lambda_0/D)
% y_fib = info.y_fib;

actxc_fib = info.actxc_fib;
ang_fib = info.ang_fib;

useGPU = info.useGPU;

RHO = info.RHO ;
THETA = info.THETA;
N = info.N;
lambda0 = info.lambda0 ;
useApodizer = info.useApodizer;
FPM = info.FPM;
LPM = info.LPM ;
outDir = info.outDir;
xvals = info.xvals;
yvals = info.yvals;
numOfWavelengths = info.numOfWavelengths;

lam_arr = info.lam_arr ;

% Model WF with flat DM, WF0, we need this to compute Gu, since Gu:
%Gu = WF_DM - WF0
normPower = info.normPower;

Nact = 12;    

fiberDiam_pix = fiberDiam*lambdaOverD;

% [THETA_fib,RHO_fib] = cart2pol(X - x_fib * lambdaOverD, Y);
% fibermode0 = sqrt(2/(pi*(fiberDiam_pix/2)^2))* ...
%     exp(-(RHO_fib/(fiberDiam_pix/2)).^2);
fibermode0 = info.fibermode0;

ac_spac = info.ac_spac;%round(2*apRad/Nact);
infl = loadInfluenceFunction( 'influence_dm5v2.fits', ac_spac );

posDM_x = info.posDM_x;
posDM_y = info.posDM_y;

num_DM_shapes = 4;
ph_arr = linspace(0, 3/2*pi, num_DM_shapes);
H_mat = zeros(num_DM_shapes,2);
DeltaI_arr = zeros(num_DM_shapes,1);
% ww = x_fib;
p2v_dm = info.p2v_dm_sensing;
apRad2 = 12;
poke_amp = p2v_dm*1e-9;
DM1_strokesKK = zeros(N,N);
for KK = 1:num_DM_shapes
    ph = ph_arr(KK);
%     cosfct = cos(2*pi*[1:apRad2]/(apRad2) * ww + ph) ;
%     a = ones(apRad2,apRad2);
%     di = diag(cosfct);
%     us = a * di; 
    dm_probcosfct = hcstt_DMMapSin(1, ang_fib, actxc_fib, ph_arr(KK));
    dm_actuators_mat0 = dm_probcosfct * poke_amp;
    
    %Add the actuators heights that were already set on the DM:
    dm_actuators_mat = dm_actuators_mat0(:) ;%+ us_total;
    
    count = 0; 
    DM1_strokes = zeros(N,N);
    for ix = 1:Nact
        for iy = 1:Nact
            count = count + 1;
            xpos = round(posDM_x(ix));%round(N/2+1+(ix-Nact/2-0.5)*ac_spac);
            ypos = round(posDM_y(iy));%round(N/2+1+(iy-Nact/2-0.5)*ac_spac);
            DM1_strokesKK(xpos,ypos) = dm_actuators_mat(count) + DM1_strokes(xpos,ypos);
        end
    end
    surf_DM1 = conv2(DM1_strokesKK,infl,'same');
    wf2_prob_noerrors = prescription_DM1toImage_compact_vFiberCoupling_broadband( wfin_noerrors, surf_DM1, true, info);
    wf2_prob_noerrors = wf2_prob_noerrors * sqrt(normPower);

    %Gu is the effect of the DM on the image plane
    Gu = wf2_prob_noerrors-wf0;
    Gu_re = real(Gu);
    Gu_im = imag(Gu);
    
    % Measure the intensity out of the fiber for the positive probe

    int_plus = hcstt_GetIntensityFIU((+dm_actuators_mat0(:) + us_total)/1e-9,5);  % dm_actuators_mat is a 12^2x1 array with the actuators heights in nm
%     hcstt_UpdateMultiDM((+dm_actuators_mat0 + us_total)/1e-9)
%     figure(111)
%     im_cam = hcstt_TakeCamImage(false,true,0.7);
%     imagesc(im_cam(180:220,180:220))
%     axis equal
%     drawnow;
%     sz = size(im_cam);
%     hcstt_test_plotCamImage(im_cam, [outDir,'CamImage_k',int2str(KK)], sz );
%     hcstt_test_plotModelImage(wf2_prob_noerrors, [outDir,'ModelImage_k',int2str(KK)], info )

    %
    
    % Measure the intensity out of the fiber for the positive probe
    int_minus = hcstt_GetIntensityFIU((-dm_actuators_mat0(:) + us_total)/1e-9,5); % dm_actuators_mat is a 12^2x1 array with the actuators heights in nm
    %
    
    %
    DeltaI_arr(KK,1) = int_plus - int_minus;

    % Compute the ith element of the observation matrix H
    H_mat(KK, :) = 4*[sum(sum(Gu_re.*fibermode0)),sum(sum(Gu_im.*fibermode0))];
    %     
end

x_hat = pinv(H_mat)*DeltaI_arr;
% 
% wf2_prob_true = prescription_DM1toImage_compact_vFiberCoupling( wf1_werrors, zeros(N,N), true, info);
% wf2_prob_true = wf2_prob_true / sqrt(normI);
% re_true = sum(sum(real(wf2_prob_true).*fibermode0));
% im_true = sum(sum(imag(wf2_prob_true).*fibermode0));
% x_true = [re_true, im_true]
% norm = max(max(abs(wf2_prob).^2))
end