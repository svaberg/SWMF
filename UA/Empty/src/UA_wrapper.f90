!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf

module UA_wrapper

  ! Wrapper for Upper Atmosphere (UA) component

  use ModUtilities, ONLY: CON_stop

  implicit none

  private ! except

  public:: UA_set_param
  public:: UA_init_session
  public:: UA_run
  public:: UA_save_restart
  public:: UA_finalize

  ! IE Coupler:
  public :: UA_get_info_for_ie
  public :: UA_get_for_ie
  public :: UA_put_from_ie

contains
  !============================================================================
  subroutine UA_set_param(CompInfo, TypeAction)

    use CON_comp_info

    character (len=*), parameter :: NameSub='UA_set_param'

    ! Arguments
    type(CompInfoType), intent(inout):: CompInfo   ! Information for this comp.
    character (len=*), intent(in)    :: TypeAction ! What to do
    !-------------------------------------------------------------------------
    select case(TypeAction)
    case('VERSION')
       call put(CompInfo,&
            Use        =.false., &
            NameVersion='Empty', &
            Version    =0.0)

    case default
       call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')
    end select

  end subroutine UA_set_param
  !============================================================================
  subroutine UA_init_session(iSession, TimeSimulation)

    !INPUT PARAMETERS:
    integer,  intent(in) :: iSession         ! session number (starting from 1)
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='UA_init_session'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')

  end subroutine UA_init_session
  !============================================================================
  subroutine UA_finalize(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='UA_finalize'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')

  end subroutine UA_finalize
  !============================================================================
  subroutine UA_save_restart(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='UA_save_restart'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')

  end subroutine UA_save_restart
  !============================================================================
  subroutine UA_run(TimeSimulation,TimeSimulationLimit)

    !INPUT/OUTPUT ARGUMENTS:
    real, intent(inout):: TimeSimulation   ! current time of component

    !INPUT ARGUMENTS:
    real, intent(in):: TimeSimulationLimit ! simulation time not to be exceeded

    character(len=*), parameter :: NameSub='UA_run'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')

  end subroutine UA_run

  !============================================================================
  subroutine UA_get_info_for_ie(nVar, NameVar_V, nMagLat, nMagLon)
    
    !OUTPUT ARGUMENTS:
    integer, intent(out) :: nVar
    integer, intent(out), optional :: nMagLat, nMagLon
    character(len=*), intent(out), optional :: NameVar_V(:)

    character(len=*), parameter :: NameSub='UA_get_info_for_ie'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')

  end subroutine UA_get_info_for_ie

  !============================================================================
  subroutine UA_put_from_ie(Buffer_IIV, iSizeIn, jSizeIn, nVarIn, &
       NameVarIn_V, iBlock)

    !INPUT/OUTPUT ARGUMENTS:
    integer, intent(in)           :: iSizeIn, jSizeIn, nVarIn, iBlock
    real, intent(in)              :: Buffer_IIV(iSizeIn,jSizeIn,nVarIn)
    character (len=*),intent(in)  :: NameVarIn_V(nVarIn)

    character (len=*), parameter :: NameSub='UA_put_from_ie'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')
    
  end subroutine UA_put_from_ie

  !============================================================================
  subroutine UA_get_for_ie(BufferOut_IIBV, nMltIn, nLatIn, nVarIn, NameVarIn_V)

    ! INPUT ARGUMENTS:
    integer,          intent(in) :: nMltIn, nLatIn, nVarIn
    character(len=3), intent(in) :: NameVarIn_V(nVarIn)
    
    ! OUTPUT ARGUMENTS:
    real, intent(out) :: BufferOut_IIBV(nMltIn, nLatIn, 2, nVarIn)
    
    character (len=*), parameter :: NameSub='UA_get_for_ie'

    call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')
    
  end subroutine UA_get_for_ie
  
end module UA_wrapper
!==============================================================================

! The following subroutines are empty versions of those in UA/GITM2/src/
! The call to these routines is commented out in CON_couple_ie_ua.f90
!
!subroutine UA_fill_electrodynamics(UAr2_fac, UAr2_ped, UAr2_hal, &
!     UAr2_lats, UAr2_mlts)
!
!  character(len=*), parameter :: NameSub='UA_fill_electrodynamics'
!
!  call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')
!
!end subroutine UA_fill_electrodynamics
!
!!===========================================================================
!
!subroutine UA_calc_electrodynamics(UAi_nMLTs, UAi_nLats)
!
!  character(len=*), parameter :: NameSub='UA_calc_electrodynamics'
!
!  call CON_stop(NameSub//': UA_ERROR: empty version cannot be used!')
!
!end subroutine UA_calc_electrodynamics


