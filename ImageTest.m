img = h5read('D:\python-ismrmrd-server\out.h5', '/dataset/images_0/data');
test = size(img);
if length(test) == 3
    test(4) = 1;
end
figure(test(4)); 
imagesc(img(:,:,150,:,end)), axis image, colormap(gray)