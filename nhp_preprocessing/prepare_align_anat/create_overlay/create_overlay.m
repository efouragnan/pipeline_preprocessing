function create_overlay(nifti,output)

% load data
data = load_nii(nifti);
data = data.img;

% extract overlay dimensions
ind = [];
for x=1:size(data,3)
    [r,c]=find(data(:,:,x));
    ind=[ind;[r c repmat(x,length(r),1)]];
end;

ind=ind-1;

% write out
dlmwrite(output,ind,'delimiter',' ');

end