!^CFG COPYRIGHT UM
! Wrapper for an "empty" Inner Heliosphere (IH) component
!==========================================================================
subroutine SC_set_param(CompInfo, TypeAction)

  use CON_comp_info

  implicit none

  character (len=*), parameter :: NameSub='SC_set_param'

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
     call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')
  end select

end subroutine SC_set_param

!==============================================================================

subroutine SC_init_session(iSession, TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  integer,  intent(in) :: iSession         ! session number (starting from 1)
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='SC_init_session'

  call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')

end subroutine SC_init_session

!==============================================================================

subroutine SC_finalize(TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='SC_finalize'

  call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')

end subroutine SC_finalize

!==============================================================================

subroutine SC_save_restart(TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='SC_save_restart'

  call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')

end subroutine SC_save_restart

!==============================================================================

subroutine SC_run(TimeSimulation,TimeSimulationLimit)

  implicit none

  !INPUT/OUTPUT ARGUMENTS:
  real, intent(inout) :: TimeSimulation   ! current time of component

  !INPUT ARGUMENTS:
  real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

  character(len=*), parameter :: NameSub='SC_run'

  call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')

end subroutine SC_run

!===============================================================

subroutine SC_synchronize_refinement(iProc0,iCommUnion)

  implicit none
  integer, intent(in) ::iProc0,iCommUnion
  character(len=*), parameter :: NameSub='SC_synchronize_refinement'

  call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')

end subroutine SC_synchronize_refinement

subroutine SC_put_from_ih(nPartial,&
     iPutStart,&
     Put,& 
     Weight,&
     DoAdd,&
     StateSI_V,&
     nVar)
  !USES:
  integer,intent(in)::nPartial,iPutStart,nVar
  logical,intent(in)::DoAdd
  real,dimension(nVar),intent(in)::StateSI_V

  character (len=*), parameter :: NameSub='SC_put_from_ih.f90'

  call CON_stop(NameSub//': SC_ERROR: empty version cannot be used!')
end subroutine SC_put_from_ih
