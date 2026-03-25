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
        
        double filtered = alpha(mMinCutoff + mBeta * std::abs(mPrevDerivative)) * value +
                         (1.0 - alpha(mMinCutoff + mBeta * std::abs(mPrevDerivative))) * mPrevFiltered;
        
        double derivative = (filtered - mPrevFiltered) / dt;
        double filteredDerivative = alpha(mDCutoff) * derivative +
                                    (1.0 - alpha(mDCutoff)) * mPrevDerivative;
        
        mPrevValue = value;
        mPrevFiltered = filtered;
        mPrevDerivative = filteredDerivative;
        
        return filtered;
    }
    
private:
    double alpha(double cutoff) {
        return 1.0 / (1.0 + cutoff * dt);
    }
    
    double mMinCutoff;
    double mBeta;
    double mDCutoff;
    double dt;
    
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
