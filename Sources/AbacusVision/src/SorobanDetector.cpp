#include "SorobanDetector.hpp"

#if ABACUS_HAS_OPENCV
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cmath>
#include <numeric>

namespace abacus {

SorobanDetector::SorobanDetector() : params_() {}
SorobanDetector::SorobanDetector(const DetectionParams& params) : params_(params) {}
SorobanDetector::~SorobanDetector() = default;

FrameDetectionResult SorobanDetector::detectFrame(
    const cv::Mat& preprocessed,
    const cv::Mat& binary,
    const cv::Mat& edges
) {
    FrameDetectionResult result;
    result.detected = false;
    result.confidence = 0.0f;
    result.laneCount = 0;
    
    if (binary.empty()) {
        return result;
    }
    
    double imageArea = binary.cols * binary.rows;
    auto candidates = findFrameCandidates(binary, imageArea);
    
    if (candidates.empty()) {
        return result;
    }
    
    double maxArea = 0;
    std::vector<cv::Point> bestContour;
    
    for (const auto& contour : candidates) {
        double area = cv::contourArea(contour);
        if (area > maxArea) {
            maxArea = area;
            bestContour = contour;
        }
    }
    
    if (bestContour.empty()) {
        return result;
    }
    
    result.corners = orderCorners(bestContour);
    
    cv::Rect rect = cv::boundingRect(bestContour);
    result.boundingBox = Rect(
        static_cast<float>(rect.x),
        static_cast<float>(rect.y),
        static_cast<float>(rect.width),
        static_cast<float>(rect.height)
    );
    
    double areaRatio = maxArea / imageArea;
    double aspectRatio = static_cast<double>(rect.width) / rect.height;
    
    if (aspectRatio >= params_.minAspectRatio && aspectRatio <= params_.maxAspectRatio) {
        result.confidence = static_cast<float>(std::min(1.0, areaRatio * 5.0));
    } else {
        result.confidence = static_cast<float>(areaRatio * 0.5);
    }
    
    result.detected = true;
    return result;
}

std::vector<std::vector<cv::Point>> SorobanDetector::findFrameCandidates(
    const cv::Mat& binary,
    double imageArea
) {
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binary, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    std::vector<std::vector<cv::Point>> candidates;
    
    double minArea = imageArea * params_.minFrameAreaRatio;
    double maxArea = imageArea * params_.maxFrameAreaRatio;
    
    for (const auto& contour : contours) {
        double area = cv::contourArea(contour);
        
        if (area < minArea || area > maxArea) {
            continue;
        }
        
        double epsilon = params_.contourApproxEpsilon * cv::arcLength(contour, true);
        std::vector<cv::Point> approx;
        cv::approxPolyDP(contour, approx, epsilon, true);
        
        if (approx.size() != 4 || !cv::isContourConvex(approx)) {
            continue;
        }
        
        cv::Rect rect = cv::boundingRect(approx);
        double aspectRatio = static_cast<double>(rect.width) / rect.height;
        
        if (aspectRatio < params_.minAspectRatio || aspectRatio > params_.maxAspectRatio) {
            continue;
        }
        
        candidates.push_back(approx);
    }
    
    return candidates;
}

Quadrilateral SorobanDetector::orderCorners(const std::vector<cv::Point>& contour) {
    Quadrilateral quad;
    if (contour.size() != 4) return quad;
    
    cv::Point2f center(0, 0);
    for (const auto& pt : contour) {
        center.x += pt.x;
        center.y += pt.y;
    }
    center.x /= 4;
    center.y /= 4;
    
    std::vector<cv::Point> topLeft, topRight, bottomRight, bottomLeft;
    
    for (const auto& pt : contour) {
        if (pt.x < center.x && pt.y < center.y) topLeft.push_back(pt);
        else if (pt.x >= center.x && pt.y < center.y) topRight.push_back(pt);
        else if (pt.x >= center.x && pt.y >= center.y) bottomRight.push_back(pt);
        else bottomLeft.push_back(pt);
    }
    
    auto selectPoint = [](const std::vector<cv::Point>& pts, cv::Point2f def) -> Point {
        if (pts.empty()) return Point(def.x, def.y);
        return Point(static_cast<float>(pts[0].x), static_cast<float>(pts[0].y));
    };
    
    quad.topLeft = selectPoint(topLeft, cv::Point2f(0, 0));
    quad.topRight = selectPoint(topRight, cv::Point2f(100, 0));
    quad.bottomRight = selectPoint(bottomRight, cv::Point2f(100, 100));
    quad.bottomLeft = selectPoint(bottomLeft, cv::Point2f(0, 100));
    
    return quad;
}

cv::Mat SorobanDetector::warpFrame(
    const cv::Mat& original,
    const FrameDetectionResult& frame,
    int outputWidth,
    int outputHeight
) {
    if (!frame.detected || original.empty()) {
        return cv::Mat();
    }
    
    std::vector<cv::Point2f> srcPoints = {
        cv::Point2f(frame.corners.topLeft.x, frame.corners.topLeft.y),
        cv::Point2f(frame.corners.topRight.x, frame.corners.topRight.y),
        cv::Point2f(frame.corners.bottomRight.x, frame.corners.bottomRight.y),
        cv::Point2f(frame.corners.bottomLeft.x, frame.corners.bottomLeft.y)
    };
    
    std::vector<cv::Point2f> dstPoints = {
        cv::Point2f(0, 0),
        cv::Point2f(static_cast<float>(outputWidth), 0),
        cv::Point2f(static_cast<float>(outputWidth), static_cast<float>(outputHeight)),
        cv::Point2f(0, static_cast<float>(outputHeight))
    };
    
    cv::Mat M = cv::getPerspectiveTransform(srcPoints, dstPoints);
    cv::Mat warped;
    cv::warpPerspective(original, warped, M, cv::Size(outputWidth, outputHeight));
    
    return warped;
}

int SorobanDetector::detectLaneCount(const cv::Mat& warpedFrame) {
    if (warpedFrame.empty()) return 0;
    
    cv::Mat gray;
    if (warpedFrame.channels() == 3) {
        cv::cvtColor(warpedFrame, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = warpedFrame.clone();
    }
    
    cv::Mat sobelX;
    cv::Sobel(gray, sobelX, CV_32F, 1, 0, 3);
    cv::Mat absSobelX;
    cv::convertScaleAbs(sobelX, absSobelX);
    
    std::vector<int> projection(gray.cols, 0);
    for (int x = 0; x < gray.cols; ++x) {
        for (int y = 0; y < gray.rows; ++y) {
            projection[x] += absSobelX.at<uchar>(y, x);
        }
    }
    
    std::vector<int> peaks;
    int windowSize = gray.cols / 50;
    int threshold = *std::max_element(projection.begin(), projection.end()) / 3;
    
    for (int i = windowSize; i < gray.cols - windowSize; ++i) {
        bool isMax = true;
        for (int j = i - windowSize; j <= i + windowSize; ++j) {
            if (j != i && projection[j] >= projection[i]) {
                isMax = false;
                break;
            }
        }
        if (isMax && projection[i] > threshold) {
            peaks.push_back(i);
        }
    }
    
    int laneCount = static_cast<int>(peaks.size()) - 1;
    laneCount = std::max(params_.minLaneCount, std::min(params_.maxLaneCount, laneCount));
    
    return laneCount;
}

std::vector<LaneInfo> SorobanDetector::extractLanes(const cv::Mat& warpedFrame, int laneCount) {
    std::vector<LaneInfo> lanes;
    if (warpedFrame.empty() || laneCount <= 0) return lanes;
    
    int laneWidth = warpedFrame.cols / laneCount;
    
    for (int i = 0; i < laneCount; ++i) {
        LaneInfo lane;
        lane.digitIndex = laneCount - 1 - i;
        lane.boundingBox = Rect(
            static_cast<float>(i * laneWidth),
            0,
            static_cast<float>(laneWidth),
            static_cast<float>(warpedFrame.rows)
        );
        lane.value = 0;
        lane.confidence = 0.0f;
        lanes.push_back(lane);
    }
    
    return lanes;
}

std::vector<cv::Mat> SorobanDetector::extractCells(const cv::Mat& lane, LaneInfo& laneInfo) {
    std::vector<cv::Mat> cells;
    if (lane.empty()) return cells;
    
    int totalRatio = params_.upperBeadRatio + params_.beadDividerRatio + params_.lowerBeadRatio;
    int upperHeight = lane.rows * params_.upperBeadRatio / totalRatio;
    int dividerHeight = lane.rows * params_.beadDividerRatio / totalRatio;
    int lowerHeight = lane.rows * params_.lowerBeadRatio / totalRatio;
    
    cv::Rect upperRect(0, 0, lane.cols, upperHeight);
    cells.push_back(lane(upperRect).clone());
    
    int lowerStart = upperHeight + dividerHeight;
    int singleLowerHeight = lowerHeight / 4;
    
    for (int i = 0; i < 4; ++i) {
        cv::Rect lowerRect(0, lowerStart + i * singleLowerHeight, lane.cols, singleLowerHeight);
        cells.push_back(lane(lowerRect).clone());
    }
    
    return cells;
}

std::vector<int> SorobanDetector::detectLaneBoundaries(const cv::Mat& gray) {
    std::vector<int> boundaries;
    if (gray.empty()) return boundaries;
    
    std::vector<int> projection(gray.cols, 0);
    for (int x = 0; x < gray.cols; ++x) {
        for (int y = 0; y < gray.rows; ++y) {
            projection[x] += gray.at<uchar>(y, x);
        }
    }
    
    std::vector<int> smoothed(gray.cols, 0);
    int smoothWindow = 5;
    for (int i = smoothWindow; i < gray.cols - smoothWindow; ++i) {
        int sum = 0;
        for (int j = -smoothWindow; j <= smoothWindow; ++j) {
            sum += projection[i + j];
        }
        smoothed[i] = sum / (2 * smoothWindow + 1);
    }
    
    for (int i = 1; i < gray.cols - 1; ++i) {
        if (smoothed[i] < smoothed[i-1] && smoothed[i] < smoothed[i+1]) {
            boundaries.push_back(i);
        }
    }
    
    return boundaries;
}

std::vector<int> SorobanDetector::detectVerticalLines(const cv::Mat& edges) {
    std::vector<int> linePositions;
    if (edges.empty()) return linePositions;
    
    std::vector<cv::Vec4i> lines;
    cv::HoughLinesP(edges, lines, params_.houghRho, params_.houghTheta,
                    params_.houghThreshold, params_.houghMinLength, params_.houghMaxGap);
    
    for (const auto& line : lines) {
        int x1 = line[0], y1 = line[1], x2 = line[2], y2 = line[3];
        double angle = std::atan2(std::abs(y2 - y1), std::abs(x2 - x1)) * 180.0 / CV_PI;
        if (angle > 80.0) {
            linePositions.push_back((x1 + x2) / 2);
        }
    }
    
    std::sort(linePositions.begin(), linePositions.end());
    linePositions.erase(
        std::unique(linePositions.begin(), linePositions.end(),
            [](int a, int b) { return std::abs(a - b) < 10; }),
        linePositions.end()
    );
    
    return linePositions;
}

} // namespace abacus

#else // !ABACUS_HAS_OPENCV

namespace abacus {

SorobanDetector::SorobanDetector() : params_() {}
SorobanDetector::SorobanDetector(const DetectionParams& params) : params_(params) {}
SorobanDetector::~SorobanDetector() = default;

FrameDetectionResult SorobanDetector::detectFrame(const cv::Mat&, const cv::Mat&, const cv::Mat&) {
    FrameDetectionResult result;
    result.detected = false;
    return result;
}

std::vector<std::vector<cv::Point>> SorobanDetector::findFrameCandidates(const cv::Mat&, double) {
    return {};
}

Quadrilateral SorobanDetector::orderCorners(const std::vector<cv::Point>&) {
    return Quadrilateral();
}

cv::Mat SorobanDetector::warpFrame(const cv::Mat&, const FrameDetectionResult&, int, int) {
    return cv::Mat();
}

int SorobanDetector::detectLaneCount(const cv::Mat&) { return 0; }

std::vector<LaneInfo> SorobanDetector::extractLanes(const cv::Mat&, int) { return {}; }

std::vector<cv::Mat> SorobanDetector::extractCells(const cv::Mat&, LaneInfo&) { return {}; }

std::vector<int> SorobanDetector::detectLaneBoundaries(const cv::Mat&) { return {}; }

std::vector<int> SorobanDetector::detectVerticalLines(const cv::Mat&) { return {}; }

} // namespace abacus

#endif // ABACUS_HAS_OPENCV
