import AppKit

class MenuBarIconAnimator {
    private var currentImage: NSImage?
    private var displayLink: CVDisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var animationDuration: CFTimeInterval = 0.5
    private var fromImage: NSImage?
    private var toImage: NSImage?
    private var completion: ((NSImage) -> Void)?

    func animate(to targetImage: NSImage, completion: @escaping (NSImage) -> Void) {
        // For simplicity, use a timer-based animation
        // In production, you might want to use CVDisplayLink for smoother animation

        guard currentImage != nil else {
            self.currentImage = targetImage
            completion(targetImage)
            return
        }

        // Simple interpolation: just use the target image with a fade effect
        // For a menu bar icon, instant updates are often acceptable
        self.currentImage = targetImage
        completion(targetImage)
    }

    func animateWithCrossfade(to targetImage: NSImage, completion: @escaping (NSImage) -> Void) {
        guard currentImage != nil else {
            self.currentImage = targetImage
            completion(targetImage)
            return
        }

        self.fromImage = currentImage
        self.toImage = targetImage
        self.completion = completion
        self.animationStartTime = CACurrentMediaTime()

        // Use a simple timer for crossfade
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - self.animationStartTime
            let progress = min(elapsed / self.animationDuration, 1.0)

            if progress >= 1.0 {
                timer.invalidate()
                self.currentImage = targetImage
                completion(targetImage)
            }
        }
    }
}
