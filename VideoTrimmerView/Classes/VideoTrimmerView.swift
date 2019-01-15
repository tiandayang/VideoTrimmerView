//
//  VideoTrimmerView.swift
//  VideoTrimmerView
//
//  Created by 田向阳 on 2019/1/14.
//  Copyright © 2019 田向阳. All rights reserved.
//

import UIKit
import AVFoundation

protocol VideoTrimmerViewDelegate: NSObjectProtocol {
    func trimmerBeginChange()
    func trimmerViewPositionDidChange(startTime: CGFloat, endTime: CGFloat)
    func trimmerViewSliderChange(startTime: CGFloat)
}

class VideoTrimmerView: UIView {

    //MARK: Property
    open var leftThumImage: UIImage?{
        didSet{
            self.leftThumView.image = leftThumImage
        }
    }
    open var rightThumImage: UIImage?{
        didSet{
            self.rightThumView.image = rightThumImage
        }
    }
    open var sliderColor: UIColor?{
        didSet{
            self.slider.backgroundColor = sliderColor
        }
    }
    
    open var maxLength: CGFloat = 15
    open var minLength: CGFloat = 3
    open weak var delegate: VideoTrimmerViewDelegate?
    
    private lazy var imageGener: AVAssetImageGenerator? = {
        if let asset = asset {
            let gener = AVAssetImageGenerator(asset: asset)
            gener.appliesPreferredTrackTransform = true
            gener.requestedTimeToleranceBefore = CMTime.zero
            gener.requestedTimeToleranceAfter = CMTime.zero
            return gener
        }
        return nil
    }()
    
    private var panType = VideoTrimmerPanType.none
    private var asset: AVURLAsset? //视频资源
    private var thumImages = [UIImage]() //视频截图
    private var thumWidth = CGFloat(10) //左右滑块的宽度
    private let sliderWidth = CGFloat(5) //中间滑块的宽度
    private var thumImageWidth = CGFloat(40)//视频截图的宽度
    private var perFrameWidth = CGFloat(0)//每一秒多宽
    private var startTime: CGFloat = 0
    private var endTime: CGFloat = 0
    
    private var leftMaskView = UIView()  //左侧的灰色蒙版
    private var rightMaskView = UIView() //右侧滑块的宽度
    private var leftThumView = UIImageView()//左侧滑块
    private var rightThumView = UIImageView()//右侧滑块
    private var slider = UIView() //中间滑块
    
    private lazy var imageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.register(VideoTrimmerViewImageCell.self, forCellWithReuseIdentifier: "VideoTrimmerViewImageCell")
        return view
    }()
    
    //MARK:LifeCycle
    
    required convenience init(frame: CGRect,
                     videoURL: URL,
                     leftThumImage: UIImage?,
                     rightThumImage: UIImage?,
                     maxLength: CGFloat,
                     minLength: CGFloat) {
        self.init(frame: frame)
        leftThumView.image = leftThumImage
        rightThumView.image = rightThumImage
        asset = AVURLAsset(url: videoURL)
        self.maxLength = maxLength
        self.minLength = minLength
        loadThumImages()
    }
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        createUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //MARK: CreateUI
    private func createUI() {
        [imageCollectionView,leftMaskView, rightMaskView,slider, leftThumView, rightThumView].forEach { (v) in
            addSubview(v)
        }
        let maskColor = UIColor.black.withAlphaComponent(0.5)
        leftMaskView.backgroundColor = maskColor
        rightMaskView.backgroundColor = maskColor
        
        imageCollectionView.frame = CGRect(x: thumWidth, y: 0, width: width - 2 * thumWidth, height: height)
        
        leftThumView.frame = CGRect(x: 0, y: 0, width: thumWidth, height: height)
        rightThumView.frame = CGRect(x: width - thumWidth, y: 0, width: thumWidth, height: height)
        leftThumView.isUserInteractionEnabled = true
        rightThumView.isUserInteractionEnabled = true
        
        slider.backgroundColor = UIColor.white
        slider.frame = CGRect(x: thumWidth, y: 0, width: sliderWidth, height: height)
        slider.clipsToBounds = true
        slider.layer.cornerRadius = thumWidth/2
        leftMaskView.frame = CGRect(x: 0, y: 0, width: 0, height: height)
        rightMaskView.frame = CGRect(x: width, y: 0, width: 0, height: height)
 
        if #available(iOS 11.0, *) {
            imageCollectionView.contentInsetAdjustmentBehavior = .never
        }
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(PanAction))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }

}

extension VideoTrimmerView: UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UIGestureRecognizerDelegate {
    //MARK:Public Func
    
    public func updateCurrentTime(_ currentTime: Double){
        let leftOffsetSeconds = imageCollectionView.contentOffset.x / perFrameWidth
        let sliderOffset = (CGFloat(currentTime) - leftOffsetSeconds) * perFrameWidth
        slider.x = sliderOffset + thumWidth
    }
    
    //MARK: Gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: self)
        let effectWidth = CGFloat(40)
        let effectRect = CGRect(x: point.x - effectWidth/2, y: 0, width: effectWidth, height: height)
        if effectRect.intersects(leftThumView.frame) || effectRect.intersects(rightThumView.frame) || effectRect.intersects(slider.frame){
            return true
        }else{
            return false
        }
    }
    
    @objc private func PanAction(sender: UIPanGestureRecognizer){
        switch sender.state {
        case .began:
            let point = sender.location(in: self)
            let effectWidth = CGFloat(40)
            let effectRect = CGRect(x: point.x - effectWidth/2, y: 0, width: effectWidth, height: height)
            if effectRect.intersects(leftThumView.frame) {
                panType = .leftThum
                imageCollectionView.isScrollEnabled = false
            } else if effectRect.intersects(rightThumView.frame){
                panType = .rightThum
                imageCollectionView.isScrollEnabled = false
            } else if effectRect.intersects(slider.frame){
                panType = .slider
                imageCollectionView.isScrollEnabled = false
            }else{
                imageCollectionView.isScrollEnabled = true
                panType = .none
            }
            if panType != .none {
                delegate?.trimmerBeginChange()
            }
            break
        case .changed:
            switch panType {
            case .leftThum:
                let point = sender.location(in: self)
                let minX = CGFloat(0)
                let maxX =  rightThumView.x -  minLength * perFrameWidth - thumWidth
                var leftX = point.x
                if point.x < minX{
                    leftX = minX
                }else if point.x > maxX {
                    leftX = maxX
                }
                leftThumView.x = leftX
                leftMaskView.width = leftThumView.right
                slider.centerX = leftMaskView.right + sliderWidth/2
                break
            case .rightThum:
                let point = sender.location(in: self)
                let minX = leftThumView.right + minLength * perFrameWidth
                let maxX =  width - thumWidth
                var rightX = point.x
                if point.x < minX{
                    rightX = minX
                }else if point.x > maxX {
                    rightX = maxX
                }
                rightThumView.x = rightX
                rightMaskView.x = rightThumView.left
                rightMaskView.width = width - rightThumView.left
                break
            case .slider:
                let point = sender.location(in: self)
                let minX = thumWidth + sliderWidth/2
                let maxX =  rightThumView.x - sliderWidth/2
                if point.x >= minX && point.x <= maxX {
                    slider.centerX = point.x
                }
                
                let contentOffsetX = imageCollectionView.contentOffset.x
                let leftOffset = slider.left - thumWidth
                let startTime = (contentOffsetX + leftOffset)/perFrameWidth
                delegate?.trimmerViewSliderChange(startTime: startTime)
                break
            case .none:break
            }
            break
        case .ended,.cancelled,.failed:
            if panType == .leftThum || panType == .rightThum {
                positionDidChange()
            }
            panType = .none
            imageCollectionView.isScrollEnabled = true
            break
        default:break
        }
    }
  
    private func positionDidChange(){
        let contentOffsetX = imageCollectionView.contentOffset.x
        let leftOffset = leftThumView.right - thumWidth
        let startTime = (contentOffsetX + leftOffset)/perFrameWidth
        let rightOffset = rightThumView.left - thumWidth
        let endTime = (contentOffsetX + rightOffset)/perFrameWidth
        delegate?.trimmerViewPositionDidChange(startTime: startTime, endTime: endTime)
    }
    
    //MARK:UICollectionViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.trimmerBeginChange()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            positionDidChange()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        positionDidChange()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return thumImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoTrimmerViewImageCell", for: indexPath) as! VideoTrimmerViewImageCell
        cell.imageView.image = thumImages.dy_SafeObjectAtIndex(indexPath.item)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: thumImageWidth, height: height)
    }
    
    //MARK:loadThumImages
    private func loadThumImages(){
        guard let asset = asset, let imageGener = imageGener else { return }
        let totalDuration = CMTimeGetSeconds(asset.duration)
        if CGFloat(totalDuration) < maxLength {
            maxLength = CGFloat(totalDuration)
        }
        let scrollWidth = imageCollectionView.width
        perFrameWidth = scrollWidth/maxLength
        var contentSizeWidth = CGFloat(totalDuration) * perFrameWidth
        contentSizeWidth = contentSizeWidth < scrollWidth ? scrollWidth : contentSizeWidth
        let count = Int(contentSizeWidth/scrollWidth * 9)
        thumImageWidth = contentSizeWidth/CGFloat(count)
        
        var times = [NSValue]()
        let perFrameDuration = totalDuration/Double(count)
        for index in 0...count - 1 {
            let time = CMTimeMake(value: Int64(Double(index) * perFrameDuration) * 1000, timescale: 1000)
            times.append(NSValue(time: time))
        }
        times[0] = NSValue(time: CMTimeMake(value: Int64(100), timescale: 1000))
        imageGener.maximumSize = CGSize(width: height * 2, height: thumImageWidth * 2)
        imageGener.generateCGImagesAsynchronously(forTimes: times) { [weak self] (time1, cgImage, time2, result, error) in
            guard let `self` = self else{ return }
            if result == AVAssetImageGenerator.Result.succeeded && cgImage != nil {
                let image = UIImage(cgImage: cgImage!)
                self.thumImages.append(image)
                DispatchQueue.main.async {
                    self.imageCollectionView.reloadData()
                }
            }
        }
    }
}


class VideoTrimmerViewImageCell: UICollectionViewCell {
    //MARK: Property
    var imageView = UIImageView()
    //MARK:LifeCycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        createUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = self.bounds
    }
    
    //MARK: CreateUI
    private func createUI() {
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        contentView.addSubview(imageView)
    }
}

extension Array {
    func dy_SafeObjectAtIndex(_ index: Int) -> Element? {
        if index < 0 || index >= count {
            return nil
        }
        return self[index]
    }
}

extension UIView {
    var x : CGFloat {
        get {
            return frame.origin.x
        }
        
        set(newVal) {
            var tmpFrame : CGRect = frame
            tmpFrame.origin.x     = newVal
            frame                 = tmpFrame
        }
    }
    
    var y : CGFloat {
        get {
            return frame.origin.y
        }
        
        set(newVal) {
            var tmpFrame : CGRect = frame
            tmpFrame.origin.y     = newVal
            frame                 = tmpFrame
        }
    }
    
    var left: CGFloat {
        get {
            return x
        }
        
        set(newVal) {
            x = newVal
        }
    }
    
    var right: CGFloat {
        get {
            return x + width
        }
        
        set(newVal) {
            x = newVal - width
        }
    }
    
    var top: CGFloat {
        get {
            return y
        }
        
        set(newVal) {
            y = newVal
        }
    }
    
    var bottom: CGFloat {
        get {
            return y + height
        }
        
        set(newVal) {
            y = newVal - height
        }
    }
    
    var width: CGFloat {
        get {
            return self.bounds.width
        }
        
        set(newVal) {
            var tmpFrame : CGRect = frame
            tmpFrame.size.width   = newVal
            frame                 = tmpFrame
        }
    }
    
    var height: CGFloat {
        get {
            return self.bounds.height
        }
        
        set(newVal) {
            var tmpFrame : CGRect = frame
            tmpFrame.size.height  = newVal
            frame                 = tmpFrame
        }
    }
    
    var centerX : CGFloat {
        get {
            return center.x
        }
        
        set(newVal) {
            center = CGPoint(x: newVal, y: center.y)
        }
    }
    
    var centerY : CGFloat {
        get {
            return center.y
        }
        
        set(newVal) {
            center = CGPoint(x: center.x, y: newVal)
        }
    }
    
    var middleX : CGFloat {
        get {
            return width / 2
        }
    }
    
    var middleY : CGFloat {
        get {
            return height / 2
        }
    }
    
    var middlePoint : CGPoint {
        get {
            return CGPoint(x: middleX, y: middleY)
        }
    }
    
}

enum VideoTrimmerPanType {
    case leftThum
    case slider
    case rightThum
    case none
}

