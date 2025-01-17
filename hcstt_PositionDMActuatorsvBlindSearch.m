%{
%}

function [posDM_x,posDM_y,ac_spac] = hcstt_PositionDMActuatorsvBlindSearch(N,apRad,posII)

load('DMAlign_PosActuators_Jul27')
load('DMAlign_RadCenter_Jul27')

scaleR = 0.95; % Correction to the radius

R = R*scaleR;
x = (pos_x-x_c)/R;
y = (pos_y-y_c)/R;

posDM_x0 = x*apRad;
posDM_y0 = y*apRad;

for II=1:12-1
    diff_x(II) = abs(posDM_x0(II+1)-posDM_x0(II));
    diff_y(II) = abs(posDM_y0(II+1)-posDM_y0(II));
end
ac_spac = mean(diff_x);

[delta_x,delta_y] = meshgrid(-3:0.5:3,-2:1:2);
[aux,ind] = sort(abs(delta_x(:)));
delta_x = delta_x(ind);
delta_y = delta_y(ind);
% posDM_x = sort(-posDM_x0+delta_x(posII),'descend')+N/2;
% posDM_y = sort(posDM_y0+delta_y(posII),'descend')+N/2;
posDM_x = sort(posDM_y0+delta_x(posII),'descend')+N/2;
posDM_y = sort(posDM_x0+delta_y(posII),'descend')+N/2;

end

