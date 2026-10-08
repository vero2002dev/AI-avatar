# Neural Runtime Licenses

The native app uses only human LivePortrait appearance, motion, warping, SPADE
decoder and stitching weights. No InsightFace detector, landmark weights,
XPose, voice models or unrelated generators are downloaded by our setup.

- MLX implementation: [Ivan Fioravanti / FasterLivePortrait-MLX](https://github.com/ivanfioravanti/fasterliveportrait-mlx), MIT, pinned to `d5361f4806c14fe2051eecb1dd5a89930f46db0d`.
- Converted weights: [model card](https://huggingface.co/ivanfioravanti/FasterLivePortrait-MLX-weights), declares MIT for the core human weights, pinned to `2cc2ac92c9fe65ca4fb68cb1a1556ead285e7391`.
- Original LivePortrait: [license](https://github.com/KlingAIResearch/LivePortrait/blob/main/LICENSE), MIT core; its InsightFace models have separate non-commercial restrictions and are deliberately excluded. Face detection is Apple's Vision.
- MLX: [Apple MLX](https://github.com/ml-explore/mlx), MIT.
- Python: PSF license; use a relocatable Python 3.11+ installation when packaging.
- NumPy: BSD; OpenCV: Apache 2.0. OpenCV is used for array/image conversion, **never camera acquisition**.

Setup downloads public model files only. Identity images, derived head crops and
camera pixels are never uploaded. The helper has no server or network transport;
it inherits the app sandbox and uses stdin/stdout pipes. Runtime code, licenses
and model card are copied into the local app. The CI archive has no model runtime
or private identity data. Distribution/notarization and a full dependency license
audit remain required before shipping a public installer.
