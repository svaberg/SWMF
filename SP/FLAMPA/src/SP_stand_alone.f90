!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!============================================================================!
program CON_stand_alone
  use SP_ModMain
  use SP_ModReadMhData,ONLY:read_ihdata_for_sp
  use SP_ModSetParam
  use ModIoUnit, ONLY: STDOUT_
  implicit none
  !--------------------------------------------------------------------------!
  integer:: iIter,iX
  !--------------------------------------------------------------------------!
  prefix='SP: ';iStdOut=STDOUT_   !Set the string to be printed on screen.   !
  DoTest=.false.
  call read_file('PARAM.in')
  call read_init
  call read_echo_set(.true.)
  call SP_set_parameters('READ')
  if(DoTest)write(iStdOut,'(a)')prefix//'Do the test only'
  if(DoTest)then
     !------------------------------- INIT ----------------------------------!
     call SP_diffusive_shock("INIT")
     call SP_allocate
     !-------------------------------- RUN ----------------------------------!
     ! The following is a test problem (DoTest=.true.):                      !
     ! 1D shock wave with unit speed propagates through half of the spatial  !
     ! interval (0,nX). The shock's compression ratio is set to 4.0.         !
     !-----------------------------------------------------------------------!
     do iIter=1,nX/2
        write(iStdOut,*)prefix,"iIter = ",iIter
        RhoSmooth_I(iIter) = 2.50
        if (iIter>1) then
           RhoSmooth_I(iIter-1) = 4.0
           do iX=1,iIter-1
              X_DI(1,iX) = 0.250*real(iX+3*iIter)
           end do
        end if
        call SP_diffusive_shock("RUN",real(iIter))
     end do
  else
     !------------------------------- INIT ----------------------------------!
     EInjection=1.0
     !     BOverDeltaB2=cThree
     call SP_diffusive_shock("INIT")
     iDataSet=4
     call read_ihdata_for_sp(1,5)
     RhoOld_I=RhoSmooth_I
     BOld_I=BSmooth_I
     RhoOld_I(iShock+1-nint(1.0/DsResolution):iShock)=&
          maxval(RhoOld_I(iShock+1-nint(1.0/DsResolution):iShock))
     RhoOld_I(iShock+1:iShock+nint(1.0/DsResolution))=&
          minval(RhoOld_I(iShock+1:iShock+nint(1.0/DsResolution)))
     BOld_I(iShock+1-nint(cOne/DsResolution):iShock)=&
          maxval(BOld_I(iShock+1-nint(cOne/DsResolution):iShock))
     BOld_I(iShock+1:iShock+nint(cOne/DsResolution))=&
          minval(BOld_I(iShock+1:iShock+nint(cOne/DsResolution)))
     SP_Time=DataInputTime
     DiffCoeffMin=5.0e+05*Rsun*DsResolution !m^2/s
     !-------------------------------- RUN ----------------------------------!
     do iDataSet=5,179
        write(iStdOut,*)prefix,"iIter = ",iDataSet-4
        call read_ihdata_for_sp(1,5)
        call SP_diffusive_shock("RUN",DataInputTime)
     end do
  endif
  !--------------------------------- FINALIZE -------------------------------!
  call SP_diffusive_shock("FINALIZE")
  !------------------------------------ DONE --------------------------------!
end program CON_stand_alone
!============================================================================!
subroutine CON_stop(String)
  use SP_ModMain
  implicit none
  character(LEN=*),intent(in)::String
  write(iStdOut,'(a)')String
  stop
end subroutine CON_stop
!============================================================================!
subroutine CON_set_do_test(String)
  use SP_ModMain
  implicit none
  character(LEN=*),intent(in)::String
  write(iStdOut,'(a)')String//' can not be tested'
  stop
end subroutine CON_set_do_test
