!^CFG COPYRIGHT UM
!
!QUOTE: \clearpage
!
!BOP
!
!QUOTE: \section{Time Related Variables and Methods}
!
!MODULE: CON_time - time related variables of CON
!
!DESCRIPTION:
! This module contains the time related variables of SWMF such
! as current and maximum time step and simulation time, or maximum
! CPU time allowed, etc.

!INTERFACE:
module CON_time

  !USES:
  use ModKind, ONLY: Real8_
  use ModFreq                 !!, ONLY: FreqType
  use ModTimeConvert          !!, ONLY: time_int_to_real, TimeType

  implicit none

  save

  !PUBLIC MEMBER FUNCTIONS:
  public :: init_time        ! Initialize start time
  public :: get_time         ! Access time related variables

  !PUBLIC DATA MEMBERS:

  ! The session index starting with 1
  integer :: iSession = 1

  ! Is this a time accurate run?
  logical :: DoTimeAccurate=.true.

  ! Number of time steps/iterations from the beginning
  integer :: nStep=0

  ! Number of time steps/iterations since last restart
  integer :: nIteration=0

  ! Maximum number of iterations since last restart
  integer :: MaxIteration=0

  ! Initial and current date/time
  type(TimeType) :: TimeStart, TimeCurrent

  ! Simulation time
  real :: tSimulation = 0.0

  ! Maximum simulation time
  real :: tSimulationMax = 0.0

  ! Maximum CPU time
  real(Real8_) :: CpuTimeStart    ! Initial value returned by MPI_WTIME
  real :: CpuTimeMax = -1.0       ! Maximum time allowed for the run

  ! Shall we check for the stop file?
  logical :: DoCheckStopFile = .true.

  ! How often shall we check cpu time and stop file
  ! Default is every time step
  type(FreqType):: CheckStop = FreqType(.false.,-1,-1.0,0,0.0)

  !REVISION HISTORY:
  ! 01Aug03 Aaron Ridley and G. Toth - initial implementation
  ! 22Aug03 G. Toth - added TypeFreq and is_time_to function
  ! 25Aug03 G. Toth - added adjust_freq subroutine
  ! 23Mar04 G. Toth - split CON_time into ModTime, ModFreq and CON_time
  ! 26Mar04 G. Toth - added get_time access method
  !EOP

  character(len=*), parameter, private :: NameMod='CON_time'

contains

  !BOP ========================================================================
  !IROUTINE: init_time - initialize start time
  !INTERFACE:
  subroutine init_time
    !EOP
    character (len=*), parameter :: NameSub = NameMod//'::init_time'

    !BOC
    TimeStart % iYear   = 2000
    TimeStart % iMonth  = 3
    TimeStart % iDay    = 21
    TimeStart % iHour   = 10
    TimeStart % iMinute = 45
    TimeStart % iSecond = 0
    TimeStart % FracSecond = 0.0

    call time_int_to_real(TimeStart)
    !EOC

  end subroutine init_time

  !BOP ========================================================================
  !IROUTINE: get_time - get time related parameters
  !INTERFACE:
  subroutine get_time(&
       DoTimeAccurateOut,tSimulationOut,TimeStartOut,TimeCurrentOut,&
       tStartOut, tCurrentOut, nStepOut)

    !OUTPUT ARGUMENTS:
    logical,          optional, intent(out) :: DoTimeAccurateOut
    real,             optional, intent(out) :: tSimulationOut
    type(TimeType),   optional, intent(out) :: TimeStartOut
    real(Real8_),     optional, intent(out) :: tStartOut
    type(TimeType),   optional, intent(out) :: TimeCurrentOut
    real(Real8_),     optional, intent(out) :: tCurrentOut
    integer,          optional, intent(out) :: nStepOut
    !EOP
    !-------------------------------------------------------------------------

    if(present(tSimulationOut))    tSimulationOut    = tSimulation
    if(present(tSimulationOut))    tSimulationOut    = tSimulation
    if(present(TimeCurrentOut))    TimeCurrentOut    = TimeCurrent
    if(present(tCurrentOut))       tCurrentOut       = TimeCurrent % Time
    if(present(TimeStartOut))      TimeStartOut      = TimeStart
    if(present(tStartOut))         tStartOut         = TimeStart % Time
    if(present(nStepOut))          nStepOut          = nStep

  end subroutine get_time

end module CON_time
