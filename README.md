# UltrasoundFascicleStrain
This MATLAB program estimates muscle fascicle strain from ultrasound B-mode videos by tracking multiple feature points within a user-defined region of interest (ROI). The algorithm combines feature tracking, principal component analysis (PCA), and geometric projection to compute continuous strain time-series and visualize deformation dynamics.
**estimateFascicleStrain.mlx** is the main script of this repository.
It internally calls **getEchoImgInfo.mlx**, which extracts essential ultrasound image parameters (e.g., pixel size and imaging depth) required for strain estimation.
