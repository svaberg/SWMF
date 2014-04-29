!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
! Wrapper for the empty PTOM (PT) component
!==========================================================================
module PT_wrapper

  implicit none

contains
  subroutine PT_set_param(CompInfo, TypeAction)

    use CON_comp_info

    character (len=*), parameter :: NameSub='PT_set_param'

    ! Arguments
    type(CompInfoType), intent(inout) :: CompInfo   ! Information for this comp.
    character (len=*), intent(in)     :: TypeAction ! What to do
    !-------------------------------------------------------------------------
    select case(TypeAction)
    case('VERSION')
       call put(CompInfo,&
            Use        =.false., &
            NameVersion='Empty', &
            Version    =0.0)

    case default
       call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')
    end select

  end subroutine PT_set_param

  !==============================================================================

  subroutine PT_init_session(iSession, TimeSimulation)

    !INPUT PARAMETERS:
    integer,  intent(in) :: iSession         ! session number (starting from 1)
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='PT_init_session'

    call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')

  end subroutine PT_init_session

  !==============================================================================

  subroutine PT_finalize(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='PT_finalize'

    call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')

  end subroutine PT_finalize

  !==============================================================================

  subroutine PT_save_restart(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='PT_save_restart'

    call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')

  end subroutine PT_save_restart

  !==============================================================================

  subroutine PT_run(TimeSimulation,TimeSimulationLimit)

    !INPUT/OUTPUT ARGUMENTS:
    real, intent(inout) :: TimeSimulation   ! current time of component

    !INPUT ARGUMENTS:
    real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

    character(len=*), parameter :: NameSub='PT_run'

    call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')

  end subroutine PT_run

  !==============================================================================
  subroutine PT_get_grid_info(nDimOut, iGridOut, iDecompOut)

    integer, intent(out):: nDimOut    ! grid dimensionality
    integer, intent(out):: iGridOut   ! grid index (increases with AMR)
    integer, intent(out):: iDecompOut ! decomposition index

    character(len=*), parameter :: NameSub = 'PT_get_grid_info'

    call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')

  end subroutine PT_get_grid_info
  !==============================================================================
  subroutine PT_put_from_gm( &
       NameVar, nVar, nPoint, Data_VI, iPoint_I, Pos_DI)

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVar    ! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI
    real,    intent(in), optional:: Data_VI(:,:)        ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)    ! Order of data
    real, intent(out), optional, allocatable:: Pos_DI(:,:) ! Positions

    character(len=*), parameter :: NameSub='PT_put_from_gm'

    call CON_stop(NameSub//': PT_ERROR: empty version cannot be used!')

  end subroutine PT_put_from_gm

end module PT_wrapper
