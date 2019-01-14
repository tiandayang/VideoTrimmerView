## VideoTrimmerView  
* 视频裁剪的View 
```objectivec

trimmerView = VideoTrimmerView(frame: CGRect(x: 14, y: view.height - 50 - 54, width: view.width - 2 * 14, height: 50), videoURL: URL(fileURLWithPath: path), leftThumImage: UIImage(named: "video_crop_l"), rightThumImage: UIImage(named: "video_crop_r"), maxLength: 15, minLength: 3)

trimmerView.delegate = self

delegate :
//MARK:VideoTrimmerViewDelegate
func trimmerViewPositionDidChange(startTime: CGFloat, endTime: CGFloat) {
self.startTime = startTime
self.endTime = endTime
self.seek(self.startTime)
}
//中间滑块拖动的
func trimmerViewSliderChange(startTime: CGFloat) {
self.seek(startTime)
}
//开始时间可结束时间将要改变
func trimmerBeginChange(){
player?.pause()
removeTimer()
}

```
