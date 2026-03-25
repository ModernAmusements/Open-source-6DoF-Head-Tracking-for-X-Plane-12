#ifndef OneEuroFilter_h
#define OneEuroFilter_h

#include <cmath>
#include <algorithm>

class OneEuroFilter {
public:
    OneEuroFilter()
        : mMinCutoff(30.0)
        , mBeta(0.6)
        , mDCutoff(25.0)
        , mFirstTime(true)
        , mPrevValue(0.0)
        , mPrevFiltered(0.0)
        , mPrevDerivative(0.0)
    {
    }
    
    OneEuroFilter(double minCutoff, double beta, double dCutoff)
        : mMinCutoff(minCutoff)
        , mBeta(beta)
        , mDCutoff(dCutoff)
        , mFirstTime(true)
        , mPrevValue(0.0)
        , mPrevFiltered(0.0)
        , mPrevDerivative(0.0)
    {
    }
    
    void setParameters(double minCutoff, double beta, double dCutoff) {
        mMinCutoff = minCutoff;
        mBeta = beta;
        mDCutoff = dCutoff;
    }
    
    double filter(double value, double dt) {
        if (mFirstTime) {
            mFirstTime = false;
            mPrevValue = value;
            mPrevFiltered = value;
            return value;
        }
        
        double e = mMinCutoff + mBeta * std::abs(mPrevDerivative);
        
        double filtered = alpha(e, dt) * value +
                         (1.0 - alpha(e, dt)) * mPrevFiltered;
        
        double derivative = (filtered - mPrevFiltered) / dt;
        double filteredDerivative = alpha(mDCutoff, dt) * derivative +
                                    (1.0 - alpha(mDCutoff, dt)) * mPrevDerivative;
        
        mPrevValue = value;
        mPrevFiltered = filtered;
        mPrevDerivative = filteredDerivative;
        
        return filtered;
    }
    
private:
    double alpha(double cutoff, double deltaTime) {
        double tau = 1.0 / (2.0 * M_PI * cutoff);
        return 1.0 / (1.0 + tau / deltaTime);
    }
    
    double mMinCutoff;
    double mBeta;
    double mDCutoff;
    
    bool mFirstTime;
    double mPrevValue;
    double mPrevFiltered;
    double mPrevDerivative;
};

class OneEuroFilterVector3 {
public:
    OneEuroFilterVector3()
        : mFilterX(30.0, 0.6, 25.0)
        , mFilterY(30.0, 0.6, 25.0)
        , mFilterZ(30.0, 0.6, 25.0)
    {
    }
    
    void setParameters(double minCutoff, double beta, double dCutoff) {
        mFilterX.setParameters(minCutoff, beta, dCutoff);
        mFilterY.setParameters(minCutoff, beta, dCutoff);
        mFilterZ.setParameters(minCutoff, beta, dCutoff);
    }
    
    void filter(double& x, double& y, double& z, double dt) {
        x = mFilterX.filter(x, dt);
        y = mFilterY.filter(y, dt);
        z = mFilterZ.filter(z, dt);
    }
    
private:
    OneEuroFilter mFilterX;
    OneEuroFilter mFilterY;
    OneEuroFilter mFilterZ;
};

#endif
