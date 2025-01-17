function [ arrayOut ] = hexSegMirror_addHexagon( cenrow, cencol, hexFlatDiam, arrayIn)
%hexSegMirror_addHexagon Adds hexagon to arrayIn, centered at (cenrow,
%cencol), with segment width 'hexFlatDiam'.
%   Inputs:
%   cenrow - row of hexagon center (samples)
%   cencol - column of hexagon center (samples)
%   hexFlatDiam - flat to flat width of the hexagonal segment (samples)
%   arrayIn - Input array
%   
%   Coordinate system origin: (rows/2+1, cols/2+1)

    [rows,cols]=size(arrayIn);

    [X,Y] = meshgrid(-cols/2:cols/2-1,-rows/2:rows/2-1); % Grids with Cartesian (x,y) coordinates 

    RHOprime = sqrt((X-cencol).^2+(Y-cenrow).^2);
    THETA = atan2(Y-cenrow,X-cencol); 

    HEX = exp(-(RHOprime.*sin(THETA)/(hexFlatDiam/2)).^1000)...
        .*exp(-(RHOprime.*cos(THETA-pi/6)/(hexFlatDiam/2)).^1000)...
        .*exp(-(RHOprime.*cos(THETA+pi/6)/(hexFlatDiam/2)).^1000);

    arrayOut = arrayIn + HEX;
end

