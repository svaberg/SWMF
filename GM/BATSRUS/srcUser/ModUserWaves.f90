!This code is a copyright protected software (c) 2002- University of Michigan
!========================================================================
! Revision history:
! Nov. 2010 Rona Oran - 1. Added user problem AdvectSphere and comparison
!                       to exact solution for this test problem.
!                       2. Allow user to choose the unit of length used
!                       in input commands #WAVE, #WAVE2 and #ADVECTSPHERE,
!                       without affecting the actual normalization in BATSRUS.
!                       This simplifies the way IC's are set up in the input 
!                       file. This option is useful in case this user module
!                       is used by two coupled components with different
!                       normalizations. 
!
!                       USAGE:
!                       #USERINPUTUNITX
!                       T            UseUserInputUnitX
!                       String       TypeInputUnitX
!                       real         UnitXSi
!
!                       If UseUSerInputUnitX = T the String is read.
!                       String specifies the input unit of length.
!                       Options are: rPlanet, rBody, rSun, cAU, Si.
!                       In case String='Si', the third parameter is
!                       read, allowing any value in Si units to be chosen.       
! ======================================================================
module ModUser

  use ModUserEmpty,               &
       IMPLEMENTED1 => user_read_inputs,                &
       IMPLEMENTED2 => user_set_ics,                    &
       IMPLEMENTED3 => user_get_log_var,                &
       IMPLEMENTED4 => user_get_b0,                     &
       IMPLEMENTED5 => user_set_face_boundary,          &
       IMPLEMENTED6 => user_set_cell_boundary,          &
       IMPLEMENTED7 => user_amr_criteria,               &
       IMPLEMENTED8 => user_set_plot_var,               &
       IMPLEMENTED9 => user_update_states

  use ModSize,       ONLY: x_, y_, z_
  use ModVarIndexes, ONLY: nVar

  include 'user_module.h' !list of public methods

  !\
  ! Here you must define a user routine Version number and a 
  ! descriptive string.
  !/
  real,              parameter :: VersionUserModule = 1.3
  character (len=*), parameter :: NameUserModule = &
       'Waves and GEM, Yingjuan Ma'

  character (len=20)  :: UserProblem='wave'

  real                :: Width, Amplitude, Phase, &
       LambdaX, LambdaY, LambdaZ
  real,dimension(nVar):: Width_V=0.0, Ampl_V=0.0, Phase_V=0.0, &
       x_V=0.0, y_V=0.0, z_V=0.0, KxWave_V=0.0, KyWave_V=0.0, KzWave_V=0.0
  integer   :: iPower_V(nVar)=1
  integer   :: iVar             
  logical   :: DoInitialize=.true.

  ! GEM challenge parameters
  real      :: Lambda0=0.5, Az=0.1, Tp=0.5 , B0=1.0  
  real      :: GemEps = 0.0

  ! The (rotated) unperturbed initial state with primitive variables
  real      :: PrimInit_V(nVar)

  ! Velocity of wave (default is set for right going whistler wave test)
  real      :: Velocity = 169.344

  ! Entropy constant for isentropic initial condition. Only used if positive.
  real      :: EntropyConstant = -1.0

  ! Integrate sin / cos wave over cell if true
  logical   :: DoIntegrateWave = .false.

  ! Variables used by the user problem AdvectSphere                           
  real      :: pBackgrndIo, uBackgrndIo, FlowAngleTheta, FlowAnglePhi
  real      :: NumDensBackgrndIo, NumDensMaxIo
  real      :: rSphere, rSphereIo, RhoBackgrndNo, RhoMaxNo, UxNo, UyNo, UzNo
  real      :: xSphereCenterInitIo, xSphereCenterInit
  real      :: ySphereCenterInitIo, ySphereCenterInit
  real      :: zSphereCenterInitIo, zSphereCenterInit
  logical   :: DoCalcAnalytic = .false., DoInitSphere = .false.

  ! Variables for the generalized power profile
  logical                  :: IsPowerProfile_V(nVar) = .false.
  integer, dimension(nVar) :: nPowerX_V = 1, nPowerY_V = 1, nPowerZ_V = 1
  real, dimension(nVar)    :: CoeffX_V = 0.0, CoeffY_V = 0.0, CoeffZ_V = 0.0

  ! For updating selected variables 
  character (len=30)    :: VarsUpdate
  integer, parameter    :: nVarsUpdateMax = 20
  integer               :: nVarsUpdate
  character(len=2)      :: VarsUpdate_I(nVarsUpdateMax)
  integer               :: iVarsUpdate_I(nVarsUpdateMax) = 0

  ! Enable user units of length in input file
  logical           :: UseUserInputUnitx = .false.
  character(len=20) :: TypeInputUnitX
  real              :: InputUnitXSi = 0.0

  ! aux. flags for problem types
  logical :: DoAdvectSphere, DoWave, DoPipeFlow =.false., &
       DoResistivityGaussian = .false.

  logical:: UseInitialStateDefinition = .false.


  !Variables for shockramp problem
  logical :: DoShockramp = .false.
contains

  subroutine user_read_inputs
    use ModMain
    use ModProcMH,    ONLY: iProc
    use ModReadParam
    ! use ModPhysics,  ONLY: Si2No_V, Io2Si_V,Io2No_V,&
    !      UnitRho_, UnitU_, UnitP_, UnitN_, UnitX_
    use ModNumConst,  ONLY: cTwoPi,cDegToRad
    use ModUtilities, ONLY: split_string, join_string
    use ModInitialState, ONLY: init_initial_state, read_initial_state_param

    character(len=100) :: NameCommand
    character(len=500) :: StringVar
    !-------------------------------------------------------------------------

    do
       if(.not.read_line() ) EXIT
       if(.not.read_command(NameCommand)) CYCLE
       select case(NameCommand)
       case("#STATEDEFINITION")
          UseInitialStateDefinition = .true.
          call join_string(nVar, NameVar_V(1:nVar), StringVar)
          call init_initial_state(StringVar)
          call read_initial_state_param(NameCommand)
       case("#STATEINTERFACE")
          call read_initial_state_param(NameCommand)
       case('#USERPROBLEM')
          call read_var('UserProblem',UserProblem)
       case('#GEM')
          UseUserICs  = .true.
          call read_var('Amplitude',Az)
       case('#GEMPERTURB')
          call read_var('GemEps',GemEps)
       case('#RT')
          UserProblem = 'RT'
          UseUserICs  = .true.
          call read_var('X Velocity Amplitude', Amplitude)
          call read_var('X Perturbation Width', Width)
       case('#WAVESPEED')
          call read_var('Velocity',Velocity)
       case('#ENTROPY')
          call read_var('EntropyConstant', EntropyConstant)
       case('#WAVEINTEGRAL')
          call read_var('DoIntegrateWave', DoIntegrateWave)
       case('#GAUSSIAN', '#TOPHAT')
          ! Read parameters for a tophat ampl for r/d < 1 or 
          ! a Gaussian profile multiplied by smoother: 
          !    ampl*exp(-(r/d)^2)*cos(0.25*pi*r/d) for r/d < 2
          ! where d = k.(x-xCenter) and k = 1/lambda
          UseUserICs  = .true.
          call read_var('iVar',      iVar)
          call read_var('Amplitude', Ampl_V(iVar))
          call read_var('LambdaX',   LambdaX)
          call read_var('LambdaY',   LambdaY)
          call read_var('LambdaZ',   LambdaZ)
          call read_var('CenterX',   x_V(iVar))
          call read_var('CenterY',   y_V(iVar))
          call read_var('CenterZ',   z_V(iVar))

          ! Negative Lambda sets 0 for wavenumber (constant in that direction)
          KxWave_V(iVar) = max(0.0, 1/LambdaX)
          KyWave_V(iVar) = max(0.0, 1/LambdaY)
          KzWave_V(iVar) = max(0.0, 1/LambdaZ)

          if(NameCommand == '#TOPHAT')then
             ! Setting zero value signals that this is a tophat
             iPower_V(iVar) = 0
          else
             ! Setting negative value signals that this is a Gaussian
             iPower_V(iVar) = -2
          end if

       case('#SHOCKRAMP')
          call read_var('DoShockramp', DoShockramp)
          UseUserOuterBcs = DoShockramp

       case('#WAVE','#WAVE2','#WAVE4', '#WAVE6')
          UseUserICs  = .true.
          call read_var('iVar', iVar)
          call read_var('Width', Width)
          call read_var('Amplitude', Amplitude)
          call read_var('LambdaX', LambdaX)
          call read_var('LambdaY', LambdaY)
          call read_var('LambdaZ', LambdaZ)
          call read_var('Phase',Phase)
          Width_V(iVar) = Width
          Ampl_V(iVar)  = Amplitude
          Phase_V(iVar) = Phase*cDegToRad

          if(NameCommand == '#WAVE6')then
             iPower_V(iVar) = 6
          elseif(NameCommand == '#WAVE4')then
             iPower_V(iVar) = 4
          elseif(NameCommand == '#WAVE2')then
             iPower_V(iVar) = 2
          else
             iPower_V(iVar) = 1
          end if

          ! if wavelength is smaller than 0, then the wave number is set to 0
          KxWave_V(iVar) = max(0.0, cTwoPi/LambdaX)          
          KyWave_V(iVar) = max(0.0, cTwoPi/LambdaY)          
          KzWave_V(iVar) = max(0.0, cTwoPi/LambdaZ)

       case('#USERINPUTUNITX')
          ! This option controls the normalization of the unit of length
          ! in input commands #WAVE, #WAVE2, #ADVECTSPHERE only.
          ! This will not affect the normalization of state variables.
          ! Designed to allow simple input in case two coupled components
          ! use this user module
          call read_var('UseUserInputUnitX', UseUserInputUnitx)
          if (UseUserInputUnitX) then
             call read_var('TypeInputUnitX', TypeInputUnitX)
             if(TypeInputUnitX=='Si') then
                call read_var('InputUnitXSi',InputUnitXSi)
                if(InputUnitXSi .le. 0.0) &
                     call CON_stop('InputUnitXSi <= 0 . Correct PARAM.in')
             end if
          end if

       case('#ADVECTSPHERE')
          UserProblem = 'AdvectSphere'
          call read_var('DoInitSphere',      DoInitSphere     )
          call read_var('NumDensBackgrndIo', NumDensBackgrndIo)
          call read_var('pBackgrndIo',       pBackgrndIo      )
          call read_var('uBackgrndIo',       uBackgrndIo      )
          call read_var('FlowAngleTheta',    FlowAngleTheta   )
          call read_var('FlowAnglePhi',      FlowAnglePhi     )
          call read_var('rSphereIo',         rSphereIo        )
          call read_var('NumDensMaxIo',      NumDensMaxIo     )
          call read_var('xSphereCenterInitIo', xSphereCenterInitIo)
          call read_var('ySphereCenterInitIo', ySphereCenterInitIo)
          call read_var('zSphereCenterInitIo', zSphereCenterInitIo)

       case('#ANALYTIC')
          call read_var('DoCalcAnalytic', DoCalcAnalytic)

       case('#POWERPROFILE')
          ! Read parameters for a power profile. Power is a postive or
          ! negative integer or zero (linear profile).
          UseUserICs  = .true.
          call read_var('iVar',    iVar)
          call read_var('CoeffX',  CoeffX_V(iVar))
          call read_var('nPowerX', nPowerX_V(iVar))
          if(nDim > 1) call read_var('CoeffY',  CoeffY_V(iVar))
          if(nDim > 1) call read_var('nPowerY', nPowerY_V(iVar))
          if(nDim > 2) call read_var('CoeffZ',  CoeffZ_V(iVar))
          if(nDim > 2) call read_var('nPowerZ', nPowerZ_V(iVar))

          UserProblem = 'PowerProfile'
          IsPowerProfile_V(iVar) = .true.
          
       case('#PIPEFLOW')
          call read_var('DoPipeFlow',DoPipeFlow)
          if(DoPipeFlow) UserProblem = 'PipeFlow'

       case('#UPDATEVAR')
          ! Only the states of the specified variables are updated
          call read_var('VarsUpdate', VarsUpdate)

          call split_string(VarsUpdate, nVarsUpdateMax, VarsUpdate_I, nVarsUpdate)
          do iVar = 1, nVarsUpdate
             read(VarsUpdate_I(iVar),*) iVarsUpdate_I(iVar)
          end do

       case('#USERINPUTEND')
          if(iProc==0) write(*,*)'USERINPUTEND'
          EXIT

       case default
          if(iProc==0) call stop_mpi( &
               'read_inputs: unrecognized command: '//NameCommand)
       end select
    end do
  end subroutine user_read_inputs
  !============================================================================
  subroutine user_set_ics(iBlock)

    use ModMain,     ONLY: TypeCoordSystem, GravitySi
    use ModGeometry, ONLY: x1, x2, y1, y2, z1, z2, Xyz_DGB
    use ModAdvance,  ONLY: State_VGB, RhoUx_, RhoUy_, RhoUz_, Ux_, Uy_, Uz_, &
         Bx_, By_, Bz_, rho_, Ppar_, p_, Pe_, &
         UseElectronPressure, UseAnisoPressure
    use ModProcMH,   ONLY: iProc
    use ModPhysics,  ONLY: ShockSlope, ShockLeftState_V, ShockRightState_V, &
         Si2No_V, Io2Si_V, Io2No_V, UnitRho_, UnitU_, UnitP_,UnitX_, UnitN_,&
         rPlanetSi, rBody, UnitT_, g
    use ModNumconst, ONLY: cHalfPi, cPi, cTwoPi, cDegToRad
    use ModSize,     ONLY: MinI, MaxI, MinJ, MaxJ, MinK, MaxK,nI,nJ,nK
    use ModConst,    ONLY: cProtonMass, rSun, cAu, RotationPeriodSun
    use BATL_lib,    ONLY: nDim, CoordMax_D, CoordMin_D, IsPeriodic_D, &
         CellSize_DB
    use ModInitialState, ONLY: get_initial_state

    integer, intent(in) :: iBlock

    real,dimension(nVar):: State_V, KxTemp_V, KyTemp_V
    real                :: SinSlope, CosSlope, Input2SiUnitX, OmegaSun
    real                :: x, y, z, r, r2, Lx, Ly, HalfWidth
    integer             :: i, j, k

    real :: RhoLeft, RhoRight, pLeft
    real :: ViscoCoeff = 0.0

    ! For 4th order scheme
    real:: Laplace
    real, allocatable:: State_G(:,:,:)

    character(len=*), parameter :: NameSub = 'user_set_ics'
    !--------------------------------------------------------------------------

    if(UseInitialStateDefinition)then
       do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
          x = Xyz_DGB(x_,i,j,k,iBlock)
          y = Xyz_DGB(y_,i,j,k,iBlock)
          call get_initial_state( (/x, y/), State_VGB(:,i,j,k,iBlock) )
       end do; end do; end do
    end if

    if(UseUserInputUnitX) then
       select case(TypeInputUnitX)
       case('rPlanet')
          Input2SiUnitX = rPlanetSi
       case('rBody')
          Input2SiUnitX = rBody
       case('rSun')
          Input2SiUnitX = rSun
       case('cAU')
          Input2SiUnitX = cAu
       case('Si')
          Input2SiUnitX = InputUnitXSi
       case default
          call CON_stop('TypeInputUnitX is not set, correct PARAM.in')
       end select
    end if

    select case(UserProblem)
    case('RT')
       ! Initialize Rayleigh-Taylor instability

       ! Set pressure gradient. Gravity is positive.

       ! rho      = Rholeft for x < 0 
       !          = Rhoright for x > 0
       ! pressure = pLeft + integral_x1^x2 rho*g dx 
       !          = pLeft + (x-x1)*RhoLeft*g                for x < 0
       !          = pLeft - x1*RhoLeft*g + x*RhoRight*g     for x > 0

       RhoLeft  = ShockLeftState_V(Rho_)
       RhoRight = ShockRightState_V(Rho_)
       pLeft    = ShockLeftState_V(p_)
       where(Xyz_DGB(x_,:,:,:,iBlock) <= 0.0)
          State_VGB(p_,:,:,:,iBlock) = pLeft &
               + (Xyz_DGB(x_,:,:,:,iBlock) - x1)*RhoLeft*GravitySi
       elsewhere
          State_VGB(p_,:,:,:,iBlock) = pLeft &
               + (Xyz_DGB(x_,:,:,:,iBlock)*RhoRight - x1*RhoLeft)*GravitySi
       end where
       ! Perturb velocity
       where(abs(Xyz_DGB(x_,:,:,:,iBlock)) < Width)
          State_VGB(RhoUx_,:,:,:,iBlock) = State_VGB(Rho_,:,:,:,iBlock) &
               * Amplitude * cos(cHalfPi*Xyz_DGB(x_,:,:,:,iBlock)/Width)**2 &
               * sin(cTwoPi*(Xyz_DGB(y_,:,:,:,iBlock))/(y2-y1))
       endwhere

    case('AdvectSphere')
       DoAdvectSphere = .true.
       ! This case describes an IC with uniform 1D flow of plasma in a fixed 
       ! direction, with no density, pressure gradients, or magnetic field.
       ! A sphere with higher density is embedded in the flow, initially at 
       ! xSphereCenterInit,  ySphereCenterInit, zSphereCenterInit.
       ! The density profile within the sphere is given by:
       ! rho = (RhoMax-RhoBackgrnd)* cos^2(pi*r/2 rSphere) + RhoBackgrnd

       ! Convert to normalized units and separate flow components  
       UxNo = uBackgrndIo*sin(cDegToRad*FlowAngleTheta)* &
            cos(cDegToRad*FlowAnglePhi)*Io2No_V(UnitU_)
       UyNo = uBackgrndIo*sin(cDegToRad*FlowAngleTheta)* &
            sin(cDegToRad*FlowAnglePhi)*Io2No_V(UnitU_)
       UzNo = uBackgrndIo*cos(cDegToRad*FlowAngleTheta)*Io2No_V(UnitU_)

       RhoBackgrndNo = NumDensBackgrndIo*Io2Si_V(UnitN_)* &
            cProtonMass*Si2No_V(UnitRho_) 
       RhoMaxNo       = NumDensMaxIo*Io2Si_V(UnitN_)* &
            cProtonMass*Si2No_V(UnitRho_)
       if (UseUserInputUnitX) then
          rSphere = rSphereIo*Input2SiUnitX*Si2No_V(UnitX_)
          xSphereCenterInit = xSphereCenterInitIo* &
               Input2SiUnitX*Si2No_V(UnitX_)
          ySphereCenterInit = ySphereCenterInitIo* &
               Input2SiUnitX*Si2No_V(UnitX_)
          zSphereCenterInit = zSphereCenterInitIo* &
               Input2SiUnitX*Si2No_V(UnitX_)
       else
          rSphere = rSphereIo
          xSphereCenterInit = xSphereCenterInitIo
          ySphereCenterInit = ySphereCenterInitIo
          zSphereCenterInit = zSphereCenterInitIo
       end if

       ! Start filling in cells (including ghost cells)

       if (DoInitSphere) then
          do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
             x = Xyz_DGB(x_,i,j,k,iBlock)
             y = Xyz_DGB(y_,i,j,k,iBlock)
             z = Xyz_DGB(z_,i,j,k,iBlock)
             r = sqrt((x - xSphereCenterInit)**2 + &
                  (y - ySphereCenterInit)**2 + &
                  (z - zSphereCenterInit)**2)
             if (r <= rSphere)then
                ! inside the sphere                                           
                ! State_VGB(rho_,i,j,k,iBlock) = RhoMaxNo ! for tophat
                State_VGB(rho_,i,j,k,iBlock) = RhoBackgrndNo + &
                     (RhoMaxNo - RhoBackgrndNo)* &
                     (cos(cHalfPi*r/rSphere))**2
             else
                ! in background flow                                         
                State_VGB(rho_,i,j,k,iBlock) = RhoBackgrndNo
             end if
          end do; end do ; end do
       else
          State_VGB(rho_,:,:,:,iBlock) = RhoBackgrndNo
       end if

       ! velocity
       State_VGB(RhoUx_,:,:,:,iBlock) = UxNo*State_VGB(rho_,:,:,:,iBlock) 
       State_VGB(RhoUy_,:,:,:,iBlock) = UyNo*State_VGB(rho_,:,:,:,iBlock) 
       State_VGB(RhoUz_,:,:,:,iBlock) = UzNo*State_VGB(rho_,:,:,:,iBlock)

       ! pressure
       State_VGB(p_,    :,:,:,iBlock) = pBackgrndIo*Io2No_V(UnitP_)

       if (TypeCoordSystem =='HGC') then
          ! Transform to HGC frame - initially aligned with HGI, only velocity 
          ! and/or momentum in X-Y plane should be transformed

          OmegaSun = cTwoPi/(RotationPeriodSun*Si2No_V(UnitT_))
          State_VGB(RhoUx_,:,:,:,iBlock) = State_VGB(RhoUx_,:,:,:,iBlock) &
               + State_VGB(Rho_,:,:,:,iBlock)*OmegaSun*Xyz_DGB(y_,:,:,:,iBlock)

          State_VGB(RhoUy_,:,:,:,iBlock) = State_VGB(RhoUy_,:,:,:,iBlock) &
               - State_VGB(Rho_,:,:,:,iBlock)*OmegaSun*Xyz_DGB(x_,:,:,:,iBlock)

       end if

    case('wave')

       if(DoInitialize)then
          DoWave = .true.
          DoInitialize=.false.

          if(DoIntegrateWave)then
             ! Calculate the finite volume integral of the wave over the cell
             do iVar = 1, nVar
                if(iPower_V(iVar) == 1)then
                   if(KxWave_V(iVar) > 0) then
                      HalfWidth = 0.5*KxWave_V(iVar)*CellSize_DB(x_,iBlock)
                      Ampl_V(iVar) = Ampl_V(iVar)*sin(HalfWidth) / HalfWidth
                   end if
                   if(KyWave_V(iVar) > 0) then
                      HalfWidth = 0.5*KyWave_V(iVar)*CellSize_DB(y_,iBlock)
                      Ampl_V(iVar) = Ampl_V(iVar)*sin(HalfWidth) / HalfWidth
                   end if
                   if(KzWave_V(iVar) > 0) then
                      HalfWidth = 0.5*KzWave_V(iVar)*CellSize_DB(z_,iBlock)
                      Ampl_V(iVar) = Ampl_V(iVar)*sin(HalfWidth) / HalfWidth
                   end if
                end if
             end do
          end if

          PrimInit_V = ShockLeftState_V

          if (UseUserInputUnitX) then
             ! Convert to normalized units of length
             Width_V  = Width_V*rSun*Si2No_V(UnitX_)
             KxWave_V = KxWave_V/(Input2SiUnitX*Si2No_V(UnitX_))        
             KyWave_V = KyWave_V/(Input2SiUnitX*Si2No_V(UnitX_))    
             KzWave_V = KzWave_V/(Input2SiUnitX*Si2No_V(UnitX_))    
          end if

          if(ShockSlope /= 0.0)then

             ! Make sure that the X and Y components of the momentum and
             ! magnetic field variables have consistent wave parameters
             if(Width_V(RhoUx_) > 0.0 .and. Width_V(RhoUy_) == 0.0) &
                  call copy_wave(RhoUx_, RhoUy_)
             if(Width_V(RhoUy_) > 0.0 .and. Width_V(RhoUx_) == 0.0) &
                  call copy_wave(RhoUy_, RhoUx_)
             if(Width_V(Bx_)    > 0.0 .and. Width_V(By_)    == 0.0) &
                  call copy_wave(Bx_,    By_)
             if(Width_V(By_)    > 0.0 .and. Width_V(Bx_)    == 0.0) &
                  call copy_wave(By_,    Bx_)

             CosSlope = 1.0/sqrt(1+ShockSlope**2)
             SinSlope = ShockSlope*CosSlope

             State_V = Ampl_V
             Ampl_V(RhoUx_) = CosSlope*State_V(RhoUx_)-SinSlope*State_V(RhoUy_)
             Ampl_V(RhoUy_) = SinSlope*State_V(RhoUx_)+CosSlope*State_V(RhoUy_)
             Ampl_V(Bx_)    = CosSlope*State_V(Bx_)   - SinSlope*State_V(By_)
             Ampl_V(By_)    = SinSlope*State_V(Bx_)   + CosSlope*State_V(By_)

             KxTemp_V= KxWave_V
             KyTemp_V= KyWave_V
             KxWave_V= CosSlope*KxTemp_V - SinSlope*KyTemp_V
             KyWave_V= SinSlope*KxTemp_V + CosSlope*KyTemp_V

             State_V = ShockLeftState_V
             PrimInit_V(Ux_) = CosSlope*State_V(Ux_) - SinSlope*State_V(Uy_)
             PrimInit_V(Uy_) = SinSlope*State_V(Ux_) + CosSlope*State_V(Uy_)
             PrimInit_V(Bx_) = CosSlope*State_V(Bx_) - SinSlope*State_V(By_)
             PrimInit_V(By_) = SinSlope*State_V(Bx_) + CosSlope*State_V(By_)

             !write(*,*) &
             !    'KxWave_V(Bx_:Bz_),KyWave_V(Bx_:Bz_),KzWave_V(Bx_:Bz_)=',&
             !     KxWave_V(Bx_:Bz_),KyWave_V(Bx_:Bz_),KzWave_V(Bx_:Bz_)
             !write(*,*)'       Ampl_V(Bx_:Bz_) =',       Ampl_V(Bx_:Bz_) 
             !write(*,*)'      Phase_V(Bx_:Bz_) =',       Phase_V(Bx_:Bz_)

          end if
       end if

       ! Convert momentum to velocity
       do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
          State_VGB(Ux_:Uz_,i,j,k,iBlock) = &
               State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) &
               / State_VGB(Rho_,i,j,k,iBlock)
       end do; end do; end do

       do iVar = 1, nVar
          if(iPower_V(iVar) <= 0)then
             ! iPower==0: Tophat
             ! iPower< 0: Gaussian profile multiplied by smoother: 
             !    ampl*exp(-(r/d)^2)*cos(0.25*pi*r/d) for r/d < 2
             do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
                x = Xyz_DGB(x_,i,j,k,iBlock) - x_V(iVar)
                y = Xyz_DGB(y_,i,j,k,iBlock) - y_V(iVar)
                z = Xyz_DGB(z_,i,j,k,iBlock) - z_V(iVar)
                if(IsPeriodic_D(1))then
                   if(x > +(x2-x1)/2) x = x - (x2-x1)
                   if(x < -(x2-x1)/2) x = x + (x2-x1)
                end if
                if(IsPeriodic_D(2))then
                   if(y > +(y2-y1)/2) y = y - (y2-y1)
                   if(y < -(y2-y1)/2) y = y + (y2-y1)
                end if
                if(IsPeriodic_D(3))then
                   if(z > +(z2-z1)/2) z = z - (z2-z1)
                   if(z < -(z2-z1)/2) z = z + (z2-z1)
                end if
                r2 =   (KxWave_V(iVar)*x)**2 + (KyWave_V(iVar)*y)**2 &
                     + (KzWave_V(iVar)*z)**2

                if(iPower_V(iVar) == 0)then
                   ! Top hat
                   if(r2 > 1.0) CYCLE
                   State_VGB(iVar,i,j,k,iBlock) = State_VGB(iVar,i,j,k,iBlock)&
                        + Ampl_V(iVar)
                else
                   ! Gaussian smoothed with cos^6
                   if(r2 > 4.0) CYCLE
                   r  = sqrt(r2)
                   State_VGB(iVar,i,j,k,iBlock) = State_VGB(iVar,i,j,k,iBlock)&
                        + Ampl_V(iVar)*cos(cPi*0.25*r)**6*exp(-r2)
                end if
             end do; end do; end do
          else
             ! cos^n profile
             do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
                if(KxWave_V(iVar) > 0.0)then
                   if(abs(Xyz_DGB(x_,i,j,k,iBlock) &
                        + ShockSlope*Xyz_DGB(y_,i,j,k,iBlock)) &
                        > Width_V(iVar) ) CYCLE
                elseif(KyWave_V(iVar) > 0.0)then
                   if(abs(Xyz_DGB(y_,i,j,k,iBlock)) > Width_V(iVar) ) CYCLE
                elseif(KzWave_V(iVar) > 0.0)then
                   if(abs(Xyz_DGB(z_,i,j,k,iBlock)) > Width_V(iVar) ) CYCLE
                end if

                State_VGB(iVar,i,j,k,iBlock) =        &
                     State_VGB(iVar,i,j,k,iBlock)          &
                     + Ampl_V(iVar)*cos(Phase_V(iVar)      &
                     + KxWave_V(iVar)*Xyz_DGB(x_,i,j,k,iBlock)  &
                     + KyWave_V(iVar)*Xyz_DGB(y_,i,j,k,iBlock)  &
                     + KzWave_V(iVar)*Xyz_DGB(z_,i,j,k,iBlock))**iPower_V(iVar)
             end do; end do; end do
          end if
       end do

       ! Convert velocity to momentum
       do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
          State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) = &
               State_VGB(Rho_,i,j,k,iBlock)*State_VGB(Ux_:Uz_,i,j,k,iBlock)
       end do; end do; end do

       if(EntropyConstant > 0.0)then
          do k = MinK,MaxK; do j = MinJ,MaxJ; do i = MinI,MaxI
             State_VGB(p_,i,j,k,iBlock) = &
                  EntropyConstant*State_VGB(Rho_,i,j,k,iBlock)**g
          end do; end do; end do
          ! Make sure the pressure gets integrated below
          ! This only works if the velocity is zero, so e = p/(g-1)
          iPower_V(p_) = 2*iPower_V(Rho_)
       end if

       if(DoIntegrateWave)then
          ! Convert to cell averages
          allocate(State_G(MinI:MaxI,MinJ:MaxJ,MinK:MaxK))
          do iVar = 1, nVar
             ! Tophat should not be integrated. 
             ! Pure cosine can be integrated analytically
             if(abs(iPower_V(iVar)) <= 1) CYCLE

             State_G = State_VGB(iVar,:,:,:,iBlock)
             do k=1, nK; do j=1, nJ; do i = 1, nI
                Laplace =                   State_G(i-1,j,k) + State_G(i+1,j,k)
                if(nJ > 1)Laplace=Laplace + State_G(i,j-1,k) + State_G(i,j+1,k)
                if(nK > 1)Laplace=Laplace + State_G(i,j,k-1) + State_G(i,j,k+1)
                State_VGB(iVar,i,j,k,iBlock) = &
                     (1 - nDim/12.0)*State_VGB(iVar,i,j,k,iBlock) + Laplace/24
             end do; end do; end do
          end do
          deallocate(State_G)
       end if

    case('GEM')
       !write(*,*)'GEM problem set up'
       State_VGB(Bx_,:,:,:,iBlock) = B0*tanh(Xyz_DGB(y_,:,:,:,iBlock)/Lambda0)

       ! Modify pressure(s) to balance magnetic pressure
       if(UseElectronPressure) then
          ! Distribute the correction proportionally between electrons and ions
          State_VGB(Pe_,:,:,:,iBlock) = ShockLeftState_V(Pe_)*(1.0 &
               + 0.5*(B0**2 - State_VGB(Bx_,:,:,:,iBlock)**2) &
               /(ShockLeftState_V(Pe_) + ShockLeftState_V(p_)))

          State_VGB(p_,:,:,:,iBlock) = ShockLeftState_V(p_)*(1.0 &
               + 0.5*(B0**2 - State_VGB(Bx_,:,:,:,iBlock)**2) &
               /(ShockLeftState_V(Pe_) + ShockLeftState_V(p_)))
       else
          State_VGB(p_,:,:,:,iBlock)  = ShockLeftState_V(p_) &
               + 0.5*(B0**2 - State_VGB(Bx_,:,:,:,iBlock)**2)
       end if

       if(UseAnisoPressure) &
            ! parallel pressure
            State_VGB(Ppar_,:,:,:,iBlock) = ShockLeftState_V(Ppar_)*(1.0 &
            + 0.5*(B0**2 - State_VGB(Bx_,:,:,:,iBlock)**2) &
            /ShockLeftState_V(p_))

       State_VGB(rho_,:,:,:,iBlock)= State_VGB(p_,:,:,:,iBlock)/Tp

       ! Size of the box
       Lx = x2 - x1
       Ly = y2 - y1
       !set intial perturbation
       do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
          x = Xyz_DGB(x_,i,j,k,iBlock)
          y = Xyz_DGB(y_,i,j,k,iBlock)
          ! Apply perturbation on x
          x = x + GemEps*(x-x1)*(x-x2)
          State_VGB(Bx_,i,j,k,iBlock) = State_VGB(Bx_,i,j,k,iBlock) &
               - Az* cPi/Ly *cos(cTwoPi*x/Lx) * sin(cPi*y/Ly) * (1+2*GemEps*x)
          State_VGB(By_,i,j,k,iBlock) = State_VGB(By_,i,j,k,iBlock) &
               + Az* cTwoPi/Lx * sin(cTwoPi*x/Lx) * cos(cPi*y/Ly)
       end do; end do; end do

    case('PowerProfile')
       ! Generalized power profile: 
       ! state = shockleftstate + c1*x^p1 + c2*y^p2 + c3*z^p3
       do iVar = 1, nVar
          if( .not.IsPowerProfile_V(iVar)) CYCLE
          ! set up the power profile for iVar
          do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
             State_VGB(iVar,i,j,k,iBlock) = ShockLeftState_V(iVar) &
                  + CoeffX_V(iVar)*Xyz_DGB(x_,i,j,k,iBlock)**nPowerX_V(iVar) &
                  + CoeffY_V(iVar)*Xyz_DGB(y_,i,j,k,iBlock)**nPowerY_V(iVar) &
                  + CoeffZ_V(iVar)*Xyz_DGB(z_,i,j,k,iBlock)**nPowerZ_V(iVar)
          end do; end do; end do
       end do

    case('PipeFlow')
       State_VGB(:,:,:,:,iBlock)      = 0.0
       State_VGB(Rho_,:,:,:,iBlock)   = 1.0
       State_VGB(p_,:,:,:,iBlock)     = 1.0 &
            - 0.1*(Xyz_DGB(x_,:,:,:,iBlock)-CoordMin_D(x_))/CoordMax_D(x_)
       do k = 1,nK; do j = 1,nJ; do i = MinI,MaxI
          ViscoCoeff = 1.0!Viscosity_factor(0,i,j,k,iBlock)
          if(ViscoCoeff > 0.0) then
             State_VGB(RhoUx_,i,j,k,iBlock) = &
                  0.5*(Xyz_DGB(y_,i,j,k,iBlock)**2 -CoordMax_D(y_)**2)*&
                  (State_VGB(p_,i,j,k,iBlock) -1.0) &
                  /(ViscoCoeff*(Xyz_DGB(x_,i,j,k,iBlock)-CoordMin_D(x_)))
          else
             State_VGB(RhoUx_,i,j,k,iBlock) = 0.0025
          end if
       end do; end do; end do

    case('ResistivityGaussian')
       DoResistivityGaussian = .true.

       State_VGB(Rho_,:,:,:,iBlock) = 1.0
       State_VGB(p_,:,:,:,iBlock)   = 1.0
       State_VGB(RhoUx_:RhoUz_,:,:,:,iBlock) = 0.0
       do k = 1, nK; do j = 1, nJ; do i = 1, nI
          call get_gaussian_field(i, j, k, iBlock, &
               State_VGB(Bx_:Bz_,i,j,k,iBlock))
       end do; end do; end do

    case default
       if(iProc==0) call stop_mpi( &
            'user_set_ics: undefined user problem='//UserProblem)

    end select

  end subroutine user_set_ics
  !=====================================================================
  subroutine copy_wave(iVar, jVar)

    ! Copy wave parameters from iVar to jVar for rotated problems

    integer, intent(in):: iVar, jVar
    !------------------------------------------------------------------
    Width_V(jVar)  = Width_V(iVar)
    KxWave_V(jVar) = KxWave_V(iVar)
    KyWave_V(jVar) = KyWave_V(iVar)
    KzWave_V(jVar) = KzWave_V(iVar)
    Phase_V(iVar)  = Phase_V(jVar) 
    iPower_V(jVar) = iPower_V(iVar)

  end subroutine copy_wave
  !=====================================================================
  subroutine user_set_plot_var(iBlock,NameVar,IsDimensional,&
       PlotVar_G, PlotVarBody, UsePlotVarBody,&
       NameTecVar, NameTecUnit, NameIdlUnit, IsFound)

    use ModMain,       ONLY: TypeCoordSystem
    use ModPhysics,    ONLY: NameTecUnit_V, NameIdlUnit_V, No2Io_V, No2Si_V, &
         Si2No_V, UnitRho_, UnitP_, UnitU_,  UnitT_, Gamma0
    use ModAdvance,    ONLY: State_VGB
    use ModVarIndexes, ONLY: RhoUx_, RhoUy_, RhoUz_, p_, Rho_
    use ModConst,      ONLY: RotationPeriodSun
    use ModNumConst,   ONLY: cTwoPi
    use ModGeometry,   ONLY: Xyz_DGB

    integer,          intent(in)   :: iBlock
    character(len=*), intent(in)   :: NameVar
    logical,          intent(in)   :: IsDimensional
    real,             intent(out)  :: PlotVar_G(MinI:MaxI, MinJ:MaxJ, MinK:MaxK)
    real,             intent(out)  :: PlotVarBody
    logical,          intent(out)  :: UsePlotVarBody
    character(len=*), intent(inout):: NameTecVar
    character(len=*), intent(inout):: NameTecUnit
    character(len=*), intent(inout):: NameIdlUnit
    logical,          intent(out)  :: IsFound

    real,dimension(MinI:MaxI, MinJ:MaxJ, MinK:MaxK):: RhoExact_G, RhoError_G
    real    :: FlowSpeedCell, Pressure, Density, OmegaSun
    real    :: RhoU_D(3), B_D(3)
    integer :: i, j, k
    character (len=*), parameter :: NameSub = 'user_set_plot_var'
    !-------------------------------------------------------------------
    IsFound = .true.

    if(DoCalcAnalytic .and. UserProblem == 'AdvectSphere' ) & 
         call calc_analytic_sln_sphere(iBlock,RhoExact_G,RhoError_G)

    select case(NameVar)
    case('rhoexact')
       if (.not. DoCalcAnalytic) then
          write(*,*) NameSub,': cannot calculate ',NameVar
          call CON_stop('Set #ANALYTIC to T on PARAM.in file')
       end if
       PlotVar_G = RhoExact_G*No2Io_V(UnitRho_)
       NameTecVar = 'RhoExact'
       NameTecUnit = NameTecUnit_V(UnitRho_)
       NameIdlUnit = NameIdlUnit_V(UnitRho_)
    case('rhoerr')
       if (.not. DoCalcAnalytic) then
          write(*,*) NameSub,': cannot calculate ',NameVar
          call CON_stop('Set #ANALYTIC to T on PARAM.in file')
       end if
       PlotVar_G = RhoError_G*No2Io_V(UnitRho_)
       NameTecVar = 'RhoError'
       NameTecUnit = NameTecUnit_V(UnitRho_)
       NameIdlUnit = NameIdlUnit_V(UnitRho_)

    case('mach')
       ! plot Mach number
       OmegaSun = cTwoPi/(RotationPeriodSun*Si2No_V(UnitT_))

       do k=MinK,MaxK ; do j=MinJ,MaxJ ; do i=MinI,MaxI
          Pressure = State_VGB(p_,i,j,k,iBlock)*No2Si_V(UnitP_)
          Density = State_VGB(Rho_,i,j,k,iBlock)*No2Si_V(UnitRho_)

          if (TypeCoordSystem =='HGC') then
             RhoU_D(1) = State_VGB(RhoUx_,i,j,k,iBlock) &
                  - State_VGB(Rho_,i,j,k,iBlock)*OmegaSun*Xyz_DGB(y_,i,j,k,iBlock)

             RhoU_D(2) = State_VGB(RhoUy_,i,j,k,iBlock) &
                  + State_VGB(Rho_,i,j,k,iBlock)*OmegaSun*Xyz_DGB(x_,i,j,k,iBlock)

          elseif (TypeCoordSystem == 'HGI') then 
             RhoU_D(1) = State_VGB(RhoUx_,i,j,k,iBlock) 
             RhoU_D(2) = State_VGB(RhoUy_,i,j,k,iBlock) 
          end if

          RhoU_D(3) = State_VGB(RhoUz_,i,j,k,iBlock)
          FlowSpeedCell = No2Si_V(UnitU_)*sqrt(sum(RhoU_D**2)) &
               /State_VGB(Rho_,i,j,k,iBlock)

          PlotVar_G(i,j,k) = FlowSpeedCell/sqrt(Gamma0*Pressure/Density)
       end do; end do ; end do
       NameTecVar = 'Mach'
       NameTecUnit = '--'
       NameIdlUnit = '--'

    case('bxexact')
       if(DoResistivityGaussian)then
          do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
             call get_gaussian_field(i, j, k, iBlock, B_D)
             PlotVar_G(i,j,k) = B_D(1)
          end do; end do ; end do
       end if

    case default
       IsFound = .false.
    end select

  contains
    subroutine calc_analytic_sln_sphere(iBlock,RhoExact_G,RhoError_G)

      use ModMain,       ONLY: time_simulation, TypeCoordSystem
      use ModGeometry,   ONLY: Xyz_DGB
      use ModNumConst,   ONLY: cHalfPi, cTwoPi
      use ModConst,      ONLY: RotationPeriodSun
      use ModAdvance,    ONLY: State_VGB
      use ModVarIndexes, ONLY: Rho_
      use ModPhysics,    ONLY: Si2No_V,UnitT_

      integer,intent(in)  :: iBlock
      real,dimension(MinI:MaxI,MinJ:MaxJ,MinK:MaxK),intent(out):: &
           RhoExact_G, RhoError_G

      real    :: x, y, z, t
      real    :: xSphereCenter, ySphereCenter, zSphereCenter
      real    :: rFromCenter, rSphereCenter
      real    :: PhiSphereCenterInertial, PhiSphereCenterRotating
      integer :: i, j, k

      character(len=*),parameter  :: NameSub = 'calc_analytic_sln_sphere'
      !-----------------------------------------------------------------
      ! Find current location of sphere center
      t = time_simulation*Si2No_V(UnitT_)
      xSphereCenter = xSphereCenterInit + UxNo*t
      ySphereCenter = ySphereCenterInit + UyNo*t
      zSphereCenter = zSphereCenterInit + UzNo*t

      ! transform if rotating frame
      if (TypeCoordSystem =='HGC') then       
         rSphereCenter = sqrt(xSphereCenter**2 + ySphereCenter**2)
         PhiSphereCenterInertial = atan2(ySphereCenter, xSphereCenter)
         PhiSphereCenterRotating = PhiSphereCenterInertial - &
              time_simulation*cTwoPi/RotationPeriodSun
         xSphereCenter = rSphereCenter*cos(PhiSphereCenterRotating)
         ySphereCenter = rSphereCenter*sin(PhiSphereCenterRotating)
      end if

      do k=MinK,MaxK ; do j= MinJ,MaxJ ; do i= MinI,MaxI

         x = Xyz_DGB(x_,i,j,k,iBlock)
         y = Xyz_DGB(y_,i,j,k,iBlock)
         z = Xyz_DGB(z_,i,j,k,iBlock)

         ! Chcek if this cell is inside the sphere
         rFromCenter = sqrt((x-xSphereCenter)**2 + (y-ySphereCenter)**2 + &
              (z-zSphereCenter)**2)
         if (rFromCenter <= rSphere) then
            RhoExact_G(i,j,k) = RhoBackgrndNo + (RhoMaxNo - RhoBackgrndNo)* &
                 cos(cHalfPi*rFromCenter/rSphere)**2
         else
            RhoExact_G(i,j,k) = RhoBackgrndNo
         end if
      end do; end do ; end do

      RhoError_G = RhoExact_G - State_VGB(Rho_,:,:,:,iBlock)

    end subroutine calc_analytic_sln_sphere

  end subroutine user_set_plot_var
  !=====================================================================
  subroutine user_get_log_var(VarValue, TypeVar, Radius)

    use ModMain,     ONLY: nI, nJ, nK, nBlock, Unused_B
    use ModAdvance,  ONLY: By_, State_VGB
    use ModGeometry, ONLY: z2, z1
    use BATL_lib,    ONLY: CellFace_DB, CellSize_DB, Xyz_DGB

    real, intent(out)            :: VarValue
    character (len=*), intent(in):: TypeVar
    real, intent(in), optional :: Radius

    character (len=*), parameter :: Name='user_get_log_var'

    integer :: k1, k2, iBlock
    real:: y1, y2, dy1, dy2, HalfInvWidth, Flux
    !-------------------------------------------------------------------
    HalfInvWidth = 0.5/(z2-z1)
    VarValue=0.0
    select case(TypeVar)
    case('byflux')
       do iBlock = 1, nBlock
          if(Unused_B(iBlock)) CYCLE
          y1 = Xyz_DGB(y_,1,0,1,iBlock)
          y2 = Xyz_DGB(y_,1,nJ+1,1,iBlock)

          if(y1*y2 > 0) CYCLE
          k1 = -y1/CellSize_DB(y_,iBlock)
          k2 = k1 + 1
          dy1 = abs(Xyz_DGB(y_,1,k1,1,iBlock))/CellSize_DB(y_,iBlock)
          dy2 = 1.0 - dy1
          Flux = CellFace_DB(2,iBlock)*HalfInvWidth* &
               ( dy2*sum(abs(State_VGB(By_,1:nI,k1,1:nK,iBlock))) &
               + dy1*sum(abs(State_VGB(By_,1:nI,k2,1:nK,iBlock))))
          if(k1==0 .or. k2==nJ+1) Flux = 0.5*Flux
          VarValue = VarValue + Flux
       end do
    case default
       call stop_mpi('Unknown user logvar='//TypeVar)
    end select
  end subroutine user_get_log_var

  !=====================================================================
  subroutine user_get_b0(x, y, z, B0_D)

    real, intent(in) :: x, y, z
    real, intent(out):: B0_D(3)

    B0_D = (/0.2, 0.3, 0.4/)

  end subroutine user_get_b0

  !=====================================================================

  subroutine user_set_face_boundary(VarsGhostFace_V)

    use ModMain,    ONLY: x_, y_, z_, BlkTest
    use ModFaceBoundary,  ONLY: FaceCoords_D, TimeBc, &
         iBlockBc

    real, intent(out):: VarsGhostFace_V(nVar)

    integer :: iVar
    real :: Dx
    logical :: DoTest = .false.
    !-------------------------------------------------------------------------

    DoTest = iBlockBc == BlkTest
    !DoTest = iFace == iTest .and. jFace == jTest .and. kFace == kTest .and. DoTest

    !     if(DoTest)write(*,*)'face: iFace,jFace,kFace,iSide=',&
    !          iFace,jFace,kFace,iSide
    !     DoTest = .false.

    Dx = Velocity*TimeBc

    !    if(DoTest) write(*,*)'Velocity, TimeBc, tSim, Dx=',&
    !         Velocity, TimeBc, Dx

    do iVar = 1, nVar
       ! Both of these are primitive variables
       VarsGhostFace_V(iVar) = PrimInit_V(iVar)         &
            + Ampl_V(iVar)*cos(Phase_V(iVar)            &
            + KxWave_V(iVar)*(FaceCoords_D(x_) - Dx)    &
            + KyWave_V(iVar)*FaceCoords_D(y_)           &
            + KzWave_V(iVar)*FaceCoords_D(z_))

       !       if(DoTest)write(*,*)'iVar, True, Ghost=',&
       !            iVar, VarsTrueFace_V(iVar), VarsGhostFace_V(iVar)

    end do

  end subroutine user_set_face_boundary

  !=====================================================================

  subroutine user_set_cell_boundary(iBlock,iSide, TypeBc, IsFound)

    use ModImplicit, ONLY: StateSemi_VGB
    use ModSize,     ONLY: nI, nJ, nK, x_, y_, z_
    use ModPhysics,  ONLY: Si2No_V, Io2Si_V,&
         Io2No_V, UnitRho_, UnitU_, UnitP_, UnitN_,&
         UnitT_, ShockLeftState_V, ShockRightState_V,&
         ShockSlope, ShockPosition
    use ModNumconst, ONLY: cTwoPi, cDegToRad
    use ModConst,    ONLY: cProtonMass, RotationPeriodSun

    use ModMain,     ONLY: Time_Simulation, &
         TypeCoordSystem
    use ModAdvance,  ONLY: nVar, Rho_, Ux_, Uz_, RhoUx_, RhoUz_, State_VGB,p_
    use ModGeometry, ONLY: Xyz_DGB, x1, x2, y1, y2, z1, z2, &
         r_BLK, XyzMin_D, XyzMax_D, TypeGeometry
    use ModVarIndexes
    use ModProcMH,   ONLY: iProc
    use ModEnergy,   ONLY: calc_energy_ghost
    use BATL_lib,    ONLY: CoordMax_D, CoordMin_D

    integer, intent(in) :: iBlock, iSide
    logical, intent(out) :: IsFound
    character (len=*), intent(in) :: TypeBc

    integer :: i,j,k,iVar
    real    :: Dx, x, y, z,r, rMin, rMax
    real    :: OmegaSun, phi, UxAligned, UyAligned
    real    :: ViscoCoeff = 0.0
    !    logical :: DoTest = .false.
    character (len=*), parameter :: Name='user_set_cell_boundary'

    ! variables for shockramp
    real   :: x0
    real   :: SinSlope, CosSlope
    real   :: ShockRampLeft_I(Rho_: p_), ShockRampRight_I(Rho_: p_)
    real   :: cOne = 1.0
    !-------------------------------------------------------------------------
    !    DoTest = iBlock == BlkTest
    IsFound = .true.

    if (DoShockramp) then
       SinSlope=ShockSlope/sqrt(cOne+ShockSlope**2)
       CosSlope=      cOne/sqrt(cOne+ShockSlope**2)

       ShockRampLeft_I = ShockLeftState_V(Rho_:p_)
       !Project the velocity in the shock front reference frame into the frame 
       !for computation. 
       ShockRampLeft_I(Ux_) = ShockLeftState_V(Ux_)*CosSlope 
       ShockRampLeft_I(Uy_) = ShockLeftState_V(Ux_)*SinSlope

       !The velocity is zero in the right of shock. 
       ShockRampRight_I = ShockRightState_V(Rho_:p_)
       select case (iSide)
       case(1)
          ! inflow BC for x=0
          do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, 0
             State_VGB(:,i,j,k,iBlock) = ShockRampLeft_I
             ! convert velocity into momentum.
             State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) = &
                  State_VGB(Ux_:Uz_,i,j,k,iBlock)&
                  *State_VGB(Rho_,i,j,k,iBlock)
          end do; end do; end do
       case(3)
          do k = MinK, MaxK; do j = MinJ, 0; do i = MinI, MaxI
             if (Xyz_DGB(x_,i,j,k,iBlock) <=  ShockPosition) then
                ! upstream (fixed) BC for the bottom ahead of "ShockPosition"
                State_VGB(:,i,j,k,iBlock) = ShockRampLeft_I
                State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) = &
                     State_VGB(Ux_:Uz_,i,j,k,iBlock) &
                     *State_VGB(Rho_,i,j,k,iBlock)
             else
                ! reflective BC beyond ShockPosition for the bottom
                State_VGB(:,i,j,k,iBlock) = State_VGB(:,i,1-j,k,iBlock)
                State_VGB(RhoUy_,i,j,k,iBlock) = &
                     -State_VGB(RhoUy_,i,j,k,iBlock)
             end if

          end do; end do; end do
       case(4)           
          ! x0 is the shock position at y=1 at the current simulation time. 
          ! The analytic shock speed is 20 along X.
          x0 = ShockPosition - ShockSlope*(1 + 20*time_simulation)
          do k = MinK, MaxK; do j = nJ+1, MaxJ; do i = MinI, MaxI
             if (Xyz_DGB(x_,i,j,k,iBlock) <= x0) then
                ! Upstream condition
                State_VGB(:,i,j,k,iBlock) = ShockRampLeft_I
             else
                ! Downstream condition
                State_VGB(:,i,j,k,iBlock) = ShockRampRight_I
             end if
             State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) = &
                  State_VGB(Ux_:Uz_,i,j,k,iBlock)&
                  *State_VGB(Rho_,i,j,k,iBlock)
          end do; end do; end do
       end select
    end if

    if(DoResistivityGaussian)then
       select case(TypeBc)
       case('usersemi')
          select case(iSide)
          case(2)
             do j = MinJ, MaxJ
                call get_gaussian_field(nI+1, j, 1, iBlock, &
                     StateSemi_VGB(1:3,nI+1,j,1,iBlock))
             end do
          end select
       end select

       RETURN
    end if

    Dx = Velocity*Time_Simulation 

    !Cartesian only code
    !    do i = imin1g,imax2g,sign(1,imax2g-imin1g)
    !       do j = jmin1g,jmax2g,sign(1,jmax2g-jmin1g)
    !          do k = kmin1g,kmax2g,sign(1,kmax2g-kmin1g)

    if(TypeGeometry=='spherical_lnr')then
       rMin = exp(XyzMin_D(1)); rMax = exp(XyzMax_D(1));
    else
       rMin = XyzMin_D(1); rMax = XyzMax_D(1);
    end if

    if (DoWave) then
       do i=MinI,MaxI
          do j=MinJ,MaxJ
             do k=MinK,MaxK
                x = Xyz_DGB(x_,i,j,k,iBlock)
                y = Xyz_DGB(y_,i,j,k,iBlock)
                z = Xyz_DGB(z_,i,j,k,iBlock)
                r = r_BLK(i,j,k,iBlock)
                r = alog(r)

                if( x1<x .and. x<x2 .and. y1<y .and. y<y2 .and. z1<z .and. z<z2 &
                     .and. r > rMin .and. r < rMax) CYCLE

                !             if(DoTest)write(*,*)'i,j,k,x,y,z,r=',i,j,k,x,y,z,r

                do iVar = 1, nVar

                   ! Both of these are primitive variables
                   State_VGB(iVar,i,j,k,iBlock) = PrimInit_V(iVar) &
                        + Ampl_V(iVar)*cos(Phase_V(iVar)               &
                        + KxWave_V(iVar)*(x - Dx)                      &
                        + KyWave_V(iVar)*y                             &
                        + KzWave_V(iVar)*z)
                end do
                State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) = &
                     State_VGB(Ux_:Uz_,i,j,k,iBlock)*State_VGB(Rho_,i,j,k,iBlock)
             end do
          end do
       end do
    end if

    if(DoPipeFlow) then

       select case(iSide)
       case(1)
          State_VGB(:,MinK:0,:,:,iBlock)      = 0.0
          State_VGB(Rho_,MinK:0,:,:,iBlock)   = 1.0
          State_VGB(p_,MinI:0,:,:,iBlock)     = 1.0 - 0.1*(Xyz_DGB(x_,MinI:0,:,:,iBlock)-CoordMin_D(x_))/CoordMax_D(x_)
          do k = MinK,MaxK; do j = MinJ,MaxJ; do i = MinI,0
             ViscoCoeff = 1.0!Viscosity_factor(0,i,j,k,iBlock)
             if( ViscoCoeff > 0.0 ) then
                State_VGB(RhoUx_,i,j,k,iBlock) = 0.5*(Xyz_DGB(y_,i,j,k,iBlock)**2 -CoordMax_D(y_)**2)*&
                     (State_VGB(p_,i,j,k,iBlock)-1.0)/(ViscoCoeff*(Xyz_DGB(x_,i,j,k,iBlock)-CoordMin_D(x_)))
             else
                State_VGB(RhoUx_,i,j,k,iBlock) = 0.0025
             end if

          end do; end do; end do
          call calc_energy_ghost(iBlock)
       case(2)
          State_VGB(:,nI+1,:,:,iBlock) = State_VGB(:,nI,:,:,iBlock)
          State_VGB(:,nI+2,:,:,iBlock) = State_VGB(:,nI,:,:,iBlock)
          State_VGB(p_,nI+1:MaxI,:,:,iBlock)     = 1.0 - 0.1*(Xyz_DGB(x_,nI+1:MaxI,:,:,iBlock)-CoordMin_D(x_))/CoordMax_D(x_)
          call calc_energy_ghost(iBlock)
       case(3)
          State_VGB(:,:,0,:,iBlock) = State_VGB(:,:,1,:,iBlock)
          State_VGB(:,:,-1,:,iBlock) = State_VGB(:,:,1,:,iBlock)
          State_VGB(RhoUx_:RhoUz_,:,-1:0,:,iBlock) = 0.0
       case(4)
          State_VGB(:,:,nJ+1,:,iBlock) = State_VGB(:,:,nJ,:,iBlock)
          State_VGB(:,:,nJ+2,:,iBlock) = State_VGB(:,:,nJ,:,iBlock)
          State_VGB(RhoUx_:RhoUz_,:,nJ+1:MaxJ,:,iBlock) = 0.0
       case(5)
          State_VGB(:,:,:,0,iBlock) = State_VGB(:,:,:,1,iBlock)
          State_VGB(:,:,:,-1,iBlock) = State_VGB(:,:,:,1,iBlock)
          State_VGB(RhoUx_:RhoUz_,:,:,-1:0,iBlock) = 0.0
       case(6)
          State_VGB(:,:,:,nK+1,iBlock) = State_VGB(:,:,:,nK,iBlock)
          State_VGB(:,:,:,nK+2,iBlock) = State_VGB(:,:,:,nK,iBlock)
          State_VGB(RhoUx_:RhoUz_,:,:,nK+1:MaxK,iBlock) = 0.0
       case default
          if(iProc==0) call stop_mpi( &
               'read_inputs: unrecognized command: '//Name)
       end select
    end if


    if (DoAdvectSphere) then

       ! Convert to normalized units and separate velocity components
       UxNo = uBackgrndIo*sin(cDegToRad*FlowAngleTheta)* &
            cos(cDegToRad*FlowAnglePhi)*Io2No_V(UnitU_)
       UyNo = uBackgrndIo*sin(cDegToRad*FlowAngleTheta)* &
            sin(cDegToRad*FlowAnglePhi)*Io2No_V(UnitU_)
       UzNo = uBackgrndIo*cos(cDegToRad*FlowAngleTheta)*Io2No_V(UnitU_)

       RhoBackgrndNo = NumDensBackgrndIo*Io2Si_V(UnitN_)* &
            cProtonMass*Si2No_V(UnitRho_)

       !\                                                                      
       ! Start filling in cells (including ghost cells)                       
       !/                          
       State_VGB(rho_,:,:,:,iBlock) = RhoBackgrndNo

       ! Transform to HGC frame  
       ! only velocity and/ or momentum in X-Y plane should be transformed

       if (TypeCoordSystem =='HGC') then
          OmegaSun = cTwoPi/(RotationPeriodSun*Si2No_V(UnitT_))
          phi = OmegaSun*Time_Simulation*Si2No_V(UnitT_)
          ! calculate the uniform flow in a fixed frame that is aligned with
          ! the HGC frame at this time
          UxAligned =  UxNo*cos(phi) + UyNo*sin(phi)
          UyAligned = -UxNo*sin(phi) + UyNo*cos(phi)

          State_VGB(RhoUx_,:,:,:,iBlock) = UxAligned*State_VGB(rho_,:,:,:,iBlock)
          State_VGB(RhoUy_,:,:,:,iBlock) = UyAligned*State_VGB(rho_,:,:,:,iBlock)

          ! Now transform velocity field to a rotating frame
          State_VGB(RhoUx_,:,:,:,iBlock) = State_VGB(RhoUx_,:,:,:,iBlock) &
               + State_VGB(Rho_,:,:,:,iBlock)*OmegaSun*Xyz_DGB(y_,:,:,:,iBlock)

          State_VGB(RhoUy_,:,:,:,iBlock) = State_VGB(RhoUy_,:,:,:,iBlock) &
               - State_VGB(Rho_,:,:,:,iBlock)*OmegaSun*Xyz_DGB(x_,:,:,:,iBlock)


          ! set the rest of state variables
          State_VGB(RhoUz_, :,:,:,iBlock) = UzNo
          State_VGB(Bx_:Bz_,:,:,:,iBlock) = 0.0
          State_VGB(p_,     :,:,:,iBlock) = pBackgrndIo*Io2No_V(UnitP_)

       else

          call CON_stop('You can only use user_outerbcs for ADVECTSPHERE in HGC frame')
       end if
    end if

  end subroutine user_set_cell_boundary

  !============================================================================

  subroutine user_amr_criteria(iBlock, UserCriteria, TypeCriteria, IsFound)

    use ModSize,     ONLY: nI, nJ, nK
    use ModAdvance,  ONLY: State_VGB, Rho_

    ! Variables required by this user subroutine
    integer, intent(in)          :: iBlock
    real, intent(out)            :: UserCriteria
    character (len=*),intent(in) :: TypeCriteria
    logical ,intent(inout)       :: IsFound

    real, parameter:: RhoMin = 2.0

    integer:: i, j, k
    !------------------------------------------------------------------
    IsFound = .true.

    ! If density exceeds RhoMin, refine
    UserCriteria = 1.0
    do k = 1, nK; do j= 1, nJ; do i = 1, nI
       if(State_VGB(Rho_,i,j,k,iBlock) > RhoMin) RETURN
    end do; end do; end do

    ! No need to refine
    UserCriteria = 0.0

  end subroutine user_amr_criteria

  !============================================================================

  subroutine user_update_states(iStage, iBlock)
    use ModAdvance,    ONLY: nVar, Flux_VX, Flux_VY, Flux_VZ, Source_VC
    use ModVarIndexes

    integer,intent(in)::iStage,iBlock
    integer :: iVar

    character(len=*), parameter :: NameSub = 'user_update_states'
    !--------------------------------------------------------------------------
!!!    if(maxval(iVarsUpdate_I) == 0) &
!!!         call CON_stop('Correct PARAM.in: set update variables in #UPDATEVAR')

    do iVar = 1, nVar
       if(minval(abs(iVarsUpdate_I - iVar)) /= 0)then
          Flux_VX(iVar,:,:,:) = 0.0
          Flux_VY(iVar,:,:,:) = 0.0
          Flux_VZ(iVar,:,:,:) = 0.0       
          Source_VC(iVar,:,:,:) = 0.0
       end if
    end do

    call update_states_MHD(iStage, iBlock)

  end subroutine user_update_states

  !============================================================================

  subroutine get_gaussian_field(i, j, k, iBlock, B_D)

    use ModGeometry,    ONLY: Xyz_DGB
    use ModMain,        ONLY: Time_Simulation
    use ModNumConst,    ONLY: cPi
    use ModResistivity, ONLY: Eta0

    integer, intent(in) :: i, j, k, iBlock
    real,    intent(out):: B_D(3)

    real:: Spread, Field, AmplitudeGaussian = 10.0
    !--------------------------------------------------------------------------

    Spread = 4.0*Eta0*Time_Simulation
    Field = AmplitudeGaussian/(sqrt(cPi*Spread)) &
         *exp(-Xyz_DGB(y_,i,j,k,iBlock)**2/Spread)

    B_D = (/ Field, 0.0, 0.0 /)

  end subroutine get_gaussian_field

end module ModUser
