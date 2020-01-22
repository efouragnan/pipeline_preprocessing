function prepare_resample_struct(struct,gre,resample_param_dir)

%% load GRE

G_nii = load_nii(gre) ;

if ~isempty(G_nii.hdr.hist.rot_orient)
    m_orient = G_nii.hdr.hist.rot_orient ;
else
    m_orient = [1 2 3] ;
end

GRes = G_nii.hdr.dime.pixdim(m_orient(:)+1) ;
GMat = G_nii.hdr.dime.dim(m_orient(:)+1) ;
G_nii = [];

%% load structural

R_nii = load_nii(struct);

if ~isempty(R_nii.hdr.hist.rot_orient)
    m_orient = R_nii.hdr.hist.rot_orient ;
else
    m_orient = [1 2 3] ;    
end

RRes = R_nii.hdr.dime.pixdim(m_orient(:)+1) ;
RMat = R_nii.hdr.dime.dim(m_orient(:)+1) ;
R_nii = [] ;

RMInd=find(RMat==max(RMat(:)));
RresERes = GRes(RMInd);
RresEMat = ceil(RMat(RMInd)/GRes(RMInd)*RRes(RMInd)) ;

%% write align commands

fid = fopen([resample_param_dir '/resample_params.com'],'w') ;
line1 = sprintf('%s %d %d %d \n', ...
    'set target-matrix',RresEMat(1),RresEMat(1),RresEMat(1)) ;
fprintf(fid,line1) ;
line2 = sprintf('%s %3.8f %3.8f %3.8f \n', ...
    'set target-resolution',GRes(1),GRes(1),GRes(1)) ;
fprintf(fid,line2) ;
line3 = sprintf('%s %d %d %d \n', ...
    'set source-matrix',RMat(1),RMat(2),RMat(3)) ;
fprintf(fid,line3) ;
line4 = sprintf('%s %3.8f %3.8f %3.8f \n', ...`
    'set source-resolution',RRes(1),RRes(2),RRes(3)) ;
fprintf(fid,line4) ;
fclose(fid) ;

end