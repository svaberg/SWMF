
extern const int constForwardScatteringCrossSectionLines=146;
int nForwardScatteringCrossSectionLines=constForwardScatteringCrossSectionLines;
double TotalIntegratedForwardScatteringCrossSection=0.0;

const int constCumulativeDistributionMaskList=10000;
int CumulativeDistributionMaskList=constCumulativeDistributionMaskList;
int constCumulativeDistributionMask[constCumulativeDistributionMaskList];
int *CumulativeDistributionMask=constCumulativeDistributionMask;

#ifndef _cForwardScatteringCrossSection_
#define _cForwardScatteringCrossSection_
struct cForwardScatteringCrossSection {
  double Angle,DifferentialCrossSection,CumulativeDistributionFunction,deltaCumulativeDistributionFunction;
};
#endif

cForwardScatteringCrossSection constForwardScatteringCrossSectionData[constForwardScatteringCrossSectionLines]={
    {0.0 , 293285.1002 , 0.0, 0.0},
    {0.24691 , 293285.1002 , 0.0, 0.0},
    {0.246914 , 199099.4223 , 0.0, 0.0},
    {0.493827 , 160549.8854 , 0.0, 0.0},
    {1.23457 , 1605.498854 , 0.0, 0.0},
    {1.48148 , 1021.762595 , 0.0, 0.0},
    {2.46914 , 413.8281219 , 0.0, 0.0},
    {4.69136 , 108.9883305 , 0.0, 0.0},
    {6.17284 , 65.02494597 , 0.0, 0.0},
    {8.14815 , 38.7962724 , 0.0, 0.0},
    {10.6173 , 24.16462167 , 0.0, 0.0},
    {13.5802 , 14.73058519 , 0.0, 0.0},
    {14.5679 , 11.8787297 , 0.0, 0.0},
    {15.5556 , 9.578731505 , 0.0, 0.0},
    {16.2963 , 9.175230851 , 0.0, 0.0},
    {16.7901 , 9.175230851 , 0.0, 0.0},
    {17.5309 , 9.175230851 , 0.0, 0.0},
    {18.2716 , 8.979889653 , 0.0, 0.0},
    {19.5062 , 7.724137568 , 0.0, 0.0},
    {20.4938 , 6.502554487 , 0.0, 0.0},
    {24.9383 , 4.414281248 , 0.0, 0.0},
    {25.9259 , 4.228321486 , 0.0, 0.0},
    {26.9136 , 4.050204949 , 0.0, 0.0},
    {28.642 , 3.637039352 , 0.0, 0.0},
    {29.3827 , 3.483822342 , 0.0, 0.0},
    {30.1235 , 3.409651562 , 0.0, 0.0},
    {31.1111 , 3.483822342 , 0.0, 0.0},
    {31.8519 , 3.637039352 , 0.0, 0.0},
    {32.5926 , 3.796986036 , 0.0, 0.0},
    {33.3333 , 3.796986036 , 0.0, 0.0},
    {34.321 , 3.559606573 , 0.0, 0.0},
    {34.8148 , 3.266021204 , 0.0, 0.0},
    {36.0494 , 2.633667837 , 0.0, 0.0},
    {37.7778 , 2.809299229 , 0.0, 0.0},
    {38.7654 , 2.690958499 , 0.0, 0.0},
    {39.5062 , 2.365004656 , 0.0, 0.0},
    {40.9877 , 2.078533364 , 0.0, 0.0},
    {42.2222 , 1.948587894 , 0.0, 0.0},
    {43.7037 , 1.907102344 , 0.0, 0.0},
    {46.9136 , 1.749810426 , 0.0, 0.0},
    {49.3827 , 1.537857164 , 0.0, 0.0},
    {50.6173 , 1.411019449 , 0.0, 0.0},
    {52.0988 , 1.351577645 , 0.0, 0.0},
    {53.0864 , 1.380978763 , 0.0, 0.0},
    {54.321 , 1.411019449 , 0.0, 0.0},
    {56.7901 , 1.240103405 , 0.0, 0.0},
    {58.0247 , 1.13782324 , 0.0, 0.0},
    {59.2593 , 1.089891335 , 0.0, 0.0},
    {60 , 1.11359943 , 0.0, 0.0},
    {60.7407 , 1.187863123 , 0.0, 0.0},
    {61.4815 , 1.240103405 , 0.0, 0.0},
    {62.4691 , 1.267079895 , 0.0, 0.0},
    {63.4568 , 1.240103405 , 0.0, 0.0},
    {64.6914 , 1.13782324 , 0.0, 0.0},
    {65.679 , 1.066687977 , 0.0, 0.0},
    {66.9136 , 1.021752691 , 0.0, 0.0},
    {69.3827 , 1.021752691 , 0.0, 0.0},
    {70.6173 , 1.043978609 , 0.0, 0.0},
    {72.0988 , 1.043978609 , 0.0, 0.0},
    {73.3333 , 0.978710415 , 0.0, 0.0},
    {74.5679 , 0.878871133 , 0.0, 0.0},
    {75.8025 , 0.772413757 , 0.0, 0.0},
    {77.284 , 0.724124097 , 0.0, 0.0},
    {78.5185 , 0.724124097 , 0.0, 0.0},
    {79.7531 , 0.739876102 , 0.0, 0.0},
    {82.4691 , 0.789216216 , 0.0, 0.0},
    {83.4568 , 0.755970764 , 0.0, 0.0},
    {84.4444 , 0.724124097 , 0.0, 0.0},
    {88.1481 , 0.650255449 , 0.0, 0.0},
    {90.1235 , 0.664400576 , 0.0, 0.0},
    {90.8642 , 0.650255449 , 0.0, 0.0},
    {92.0988 , 0.636411472 , 0.0, 0.0},
    {92.8395 , 0.664400576 , 0.0, 0.0},
    {93.5802 , 0.664400576 , 0.0, 0.0},
    {96.0494 , 0.609602866 , 0.0, 0.0},
    {97.284 , 0.57149048 , 0.0, 0.0},
    {98.7654 , 0.559324702 , 0.0, 0.0},
    {100 , 0.583922218 , 0.0, 0.0},
    {101.481 , 0.622863669 , 0.0, 0.0},
    {102.716 , 0.609602866 , 0.0, 0.0},
    {104.198 , 0.57149048 , 0.0, 0.0},
    {106.173 , 0.559324702 , 0.0, 0.0},
    {108.148 , 0.491574108 , 0.0, 0.0},
    {109.383 , 0.547416647 , 0.0, 0.0},
    {110.37 , 0.547416647 , 0.0, 0.0},
    {111.111 , 0.524355708 , 0.0, 0.0},
    {112.84 , 0.491574108 , 0.0, 0.0},
    {114.074 , 0.502267411 , 0.0, 0.0},
    {115.309 , 0.524355708 , 0.0, 0.0},
    {116.296 , 0.502267411 , 0.0, 0.0},
    {117.531 , 0.481108467 , 0.0, 0.0},
    {118.765 , 0.491574108 , 0.0, 0.0},
    {120.247 , 0.513192145 , 0.0, 0.0},
    {121.235 , 0.502267411 , 0.0, 0.0},
    {122.222 , 0.491574108 , 0.0, 0.0},
    {123.704 , 0.535762115 , 0.0, 0.0},
    {124.198 , 0.559324702 , 0.0, 0.0},
    {125.185 , 0.559324702 , 0.0, 0.0},
    {126.42 , 0.524355708 , 0.0, 0.0},
    {127.901 , 0.491574108 , 0.0, 0.0},
    {128.642 , 0.481108467 , 0.0, 0.0},
    {129.383 , 0.491574108 , 0.0, 0.0},
    {131.111 , 0.513192145 , 0.0, 0.0},
    {132.84 , 0.481108467 , 0.0, 0.0},
    {134.815 , 0.451030592 , 0.0, 0.0},
    {137.037 , 0.481108467 , 0.0, 0.0},
    {138.272 , 0.491574108 , 0.0, 0.0},
    {139.753 , 0.491574108 , 0.0, 0.0},
    {141.235 , 0.460840883 , 0.0, 0.0},
    {141.975 , 0.441428125 , 0.0, 0.0},
    {142.963 , 0.441428125 , 0.0, 0.0},
    {144.198 , 0.481108467 , 0.0, 0.0},
    {144.938 , 0.502267411 , 0.0, 0.0},
    {145.926 , 0.513192145 , 0.0, 0.0},
    {146.667 , 0.491574108 , 0.0, 0.0},
    {147.654 , 0.460840883 , 0.0, 0.0},
    {148.395 , 0.432030094 , 0.0, 0.0},
    {149.63 , 0.422832149 , 0.0, 0.0},
    {150.37 , 0.432030094 , 0.0, 0.0},
    {151.111 , 0.460840883 , 0.0, 0.0},
    {152.099 , 0.491574108 , 0.0, 0.0},
    {153.086 , 0.502267411 , 0.0, 0.0},
    {154.074 , 0.481108467 , 0.0, 0.0},
    {154.815 , 0.451030592 , 0.0, 0.0},
    {155.556 , 0.422832149 , 0.0, 0.0},
    {156.79 , 0.396397585 , 0.0, 0.0},
    {158.025 , 0.413830028 , 0.0, 0.0},
    {159.506 , 0.441428125 , 0.0, 0.0},
    {161.975 , 0.47086564 , 0.0, 0.0},
    {164.691 , 0.481108467 , 0.0, 0.0},
    {166.173 , 0.451030592 , 0.0, 0.0},
    {167.16 , 0.432030094 , 0.0, 0.0},
    {167.901 , 0.441428125 , 0.0, 0.0},
    {168.642 , 0.460840883 , 0.0, 0.0},
    {169.136 , 0.491574108 , 0.0, 0.0},
    {169.877 , 0.583922218 , 0.0, 0.0},
    {170.37 , 0.708707453 , 0.0, 0.0},
    {171.605 , 0.806384368 , 0.0, 0.0},
    {172.099 , 0.823925226 , 0.0, 0.0},
    {172.593 , 0.806384368 , 0.0, 0.0},
    {174.815 , 0.789216216 , 0.0, 0.0},
    {175.062 , 0.678853404 , 0.0, 0.0},
    {175.802 , 0.622863669 , 0.0, 0.0},
    {176.543 , 0.739876102 , 0.0, 0.0},
    {177.531, 1.021752691, 0.0, 0.0},
    {180.0, 1.021752691, 0.0, 0.0}};

cForwardScatteringCrossSection *ForwardScatteringCrossSectionData=constForwardScatteringCrossSectionData;