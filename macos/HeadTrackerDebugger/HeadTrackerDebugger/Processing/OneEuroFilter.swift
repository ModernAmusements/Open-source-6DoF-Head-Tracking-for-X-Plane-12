import Foundation

class OneEuroFilter {
    private var minCutoff: Double
    private var beta: Double
    private var dCutoff: Double
    
    private var firstTime: Bool = true
    private var prevValue: Double = 0
    private var prevFiltered: Double = 0
    private var prevDerivative: Double = 0
    
    init(minCutoff: Double = 1.0, beta: Double = 0.8, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    func setParameters(minCutoff: Double, beta: Double, dCutoff: Double) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    func filter(_ value: Double, dt: Double) -> Double {
        if firstTime {
            firstTime = false
            prevValue = value
            prevFiltered = value
            prevDerivative = 0
            return value
        }
        
        let effectiveDt = max(dt, 0.001)
        
        let e = minCutoff + beta * abs(prevDerivative)
        let alpha = 1.0 / (1.0 + (1.0 / (2.0 * .pi * e)) / effectiveDt)
        
        let filtered = alpha * value + (1.0 - alpha) * prevFiltered
        
        let derivative = (filtered - prevFiltered) / effectiveDt
        let alphaD = 1.0 / (1.0 + (1.0 / (2.0 * .pi * dCutoff)) / effectiveDt)
        let filteredDerivative = alphaD * derivative + (1.0 - alphaD) * prevDerivative
        
        prevValue = value
        prevFiltered = filtered
        prevDerivative = filteredDerivative
        
        return filtered
    }
    
    func reset() {
        firstTime = true
        prevValue = 0
        prevFiltered = 0
        prevDerivative = 0
    }
}

class OneEuroFilterVector3 {
    private let filterX: OneEuroFilter
    private let filterY: OneEuroFilter
    private let filterZ: OneEuroFilter
    
    init(minCutoff: Double = 1.0, beta: Double = 0.8, dCutoff: Double = 1.0) {
        filterX = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        filterY = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        filterZ = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
    }
    
    func setParameters(minCutoff: Double, beta: Double, dCutoff: Double) {
        filterX.setParameters(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        filterY.setParameters(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        filterZ.setParameters(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
    }
    
    func filter(pitch: Double, yaw: Double, roll: Double, dt: Double) -> (pitch: Double, yaw: Double, roll: Double) {
        let filteredPitch = filterX.filter(pitch, dt: dt)
        let filteredYaw = filterY.filter(yaw, dt: dt)
        let filteredRoll = filterZ.filter(roll, dt: dt)
        return (filteredPitch, filteredYaw, filteredRoll)
    }
    
    func reset() {
        filterX.reset()
        filterY.reset()
        filterZ.reset()
    }
}
