module solve

use constants
#ifdef par
use scalapack_mod
#endif
#ifdef USE_PGESVR
use pgesvr_mod
#endif

#ifdef writeserialmatrix
use netcdf
#endif

use timer_mod
implicit none


contains

    subroutine solve_lsq ()

        use aorsaNamelist, &
            only: square, magma
        use mat_fill, &
            only: A=>aMat
        use antenna, &
            only: B=>brhs, B_global=>brhs_global
        use parallel, only: NRHS

        implicit none

#ifdef writeserialmatrix
        character(len=100) :: fName 
        integer :: N_id, nc_stat, reA_id, imA_id, nc_id
#endif

        integer :: info, nRow, nCol
        integer, allocatable, dimension(:) :: ipiv, IPVT

        !   lapack variables
        
        integer :: M_, N_, LDA, LDB, MN_, LWORK, RANK
        real :: RCOND
#ifndef dblprec   
        real, allocatable :: rWork(:)
        complex, allocatable :: work(:)
#else
        real(kind=dbl), allocatable :: rWork(:)
        complex(kind=dbl), allocatable :: work(:)
#endif
        integer, allocatable, dimension(:) :: jpvt

        ! Cuda
        integer(kind=long) :: k1, k2, nb, N
        integer, external :: magma_get_zgetrf_nb
        integer :: magma_solve, magStat
        integer :: dA_dim

        nRow    = size ( A, 2 ) !nPtsX * nPtsY * 3
        nCol    = size ( A, 1 ) !nModesX * nModesY * 3

        if(square) then


            N = nRow
            LDA = max(1,N)
            LDB = max(1,N)

            write(*,*) N, NRHS, size(B,1), size(B,2)
            allocate ( IPVT(N) )
            IPVT = 0
#ifndef dblprec
            write(*,*) 'Using standard CGESV for square system'
            call cgesv ( N, NRHS, A, LDA, IPVT, B, LDB, info )
#else            
            write(*,*) 'Using standard ZGESV for square system'
            call zgesv ( N, NRHS, A, LDA, IPVT, B, LDB, info )

#ifdef writeserialmatrix
            fname = 'matrix.nc'
            nc_stat = nf90_create ( fName, nf90_clobber, nc_id )
            nc_stat = nf90_def_dim ( nc_id, "N", int(N), N_id )
            nc_stat = nf90_def_var ( nc_id, "reA", NF90_REAL, (/N_id,N_id/), reA_id )
            nc_stat = nf90_def_var ( nc_id, "imA", NF90_REAL, (/N_id,N_id/), imA_id )
            nc_stat = nf90_enddef ( nc_id ) 
            nc_stat = nf90_put_var ( nc_id, reA_id, real(A) )
            nc_stat = nf90_put_var ( nc_id, imA_id, aimag(A) )
            nc_stat = nf90_close ( nc_id ) 
#endif              

#endif
        else

            M_  = nRow
            N_  = nCol
            LDA = maxVal ( (/ 1, M_ /) )
            LDB = maxVal ( (/ 1, M_, N_ /) )
            MN_ = minVal ( (/ M_, N_ /) )
            LWORK   = MN_ + maxVal ( (/ 2 * MN_, N_ + 1, MN_ + NRHS /) )
            RCOND   = 1E-12

            allocate ( WORK ( maxVal ( (/ 1, LWORK /) ) ) )
            allocate ( RWORK ( 2 * N_ ) )
            allocate ( JPVT ( N_ ) ) 

            JPVT    = 0
            WORK    = 0
            RWORK   = 0

            write(*,*) shape ( A ), M_*N_, size(A)
#ifndef dblprec
            call cgelsy ( M_, N_, NRHS, A, LDA, B, LDB, JPVT, RCOND, RANK, &
                                WORK, LWORK, RWORK, info )
#else
            call zgelsy ( M_, N_, NRHS, A, LDA, B, LDB, JPVT, RCOND, RANK, &
                                WORK, LWORK, RWORK, info )
#endif

        endif

        if  (info/=0) then

            write(*,*) '    solve.F90: ERROR, solve did not complete successfully'
            write(*,*) '    info: ', info
            stop

        else
            write(*,*) '    LAPACK status: ', info
        endif 
        
        deallocate ( A )

        B_global = B

    end subroutine solve_lsq

#ifdef par

    subroutine solve_lsq_parallel ()

        use aorsaNamelist, &
            only: npRow, npCol, square
        use mat_fill, &
            only: A=>aMat
        use antenna, &
            only: B=>brhs, B_global=>brhs_global
        use parallel, only : iAm, ICTXT, &
                NRHS, DESCA, DESCB, RSRC, CSRC, IA, IB, JA, JB, &
                mb_A => MB, nb_A => NB, mb_B => NB, nb_B => NBRHS, &
                MYCOL, MYROW

        implicit none

        character :: trans
        integer :: m, n
#ifndef dblprec
        complex, allocatable :: work(:)
#else
        complex(kind=dbl), allocatable :: work(:)
#endif
        integer :: lWork, info
        integer :: ltau, lwf, lws, MpA0, NqA0, NRHSqB0, MpB0
        integer :: IROFFA, IAROW, IACOL, IROFFB, IBROW, IBCOL
        integer :: icoffa
        integer :: icoffb, Npb0

        integer, external :: ILCM, NUMROC, INDXG2P
        integer, allocatable :: ipiv(:)

        integer :: ii, gg
        type(timer) :: tSolve0,tSolve0_onlyfactor

#ifdef USE_GPU
        integer :: memsize,ivalue,istatus
        character(len=127) :: memsize_str
#endif
#ifdef USE_ROW_SCALING
        logical, parameter :: use_row_scaling = .true.
        real*8 :: rnorm,rnorm_inv
        integer :: iia, i, incx
        type(timer) :: tRowScale

        logical, parameter :: use_column_scaling = .false.
        integer :: j,jja,iib
        real*8 :: cnorm, cnorm_inv
        real*8, dimension(:), allocatable :: cnorm_inv_array
#endif
#ifdef USE_RCOND
        character, parameter :: norm = '1'
        integer :: lzwork,lrwork
        real*8, allocatable,dimension(:) :: rwork
        complex*16, allocatable, dimension(:) :: zwork
        complex*16 :: zwork1(1024*1024)
        real*8 :: rwork1(1024*1024)
        real*8 :: anorm, rcond
        type(timer) :: tRCond
        real :: TimeRCond

        interface
          double precision function pzlange(norm,m,n,A,ia,ja,descA,work)
          character norm
          integer ia,ja,m,n
          integer descA(*)
          double precision work(*)
          complex*16 A(*)
          end function pzlange
        end interface
#endif

        trans   = 'N'

        m   = DESCA(M_)
        n   = DESCA(N_)

        iroffa  = mod( ia-1, mb_a )
        icoffa  = mod( ja-1, nb_a )
        iarow   = indxg2p( ia, mb_a, myRow, RSRC, npRow )
        iacol   = indxg2p( ja, nb_a, myCol, CSRC, npCol )
        MpA0    = numroc( m+iroffa, mb_a, myrow, iarow, nprow )
        NqA0    = numroc( n+icoffa, nb_a, mycol, iacol, npcol )

        iroffb  = mod( ib-1, mb_b )
        icoffb  = mod( jb-1, nb_b )
        ibrow   = indxg2p( ib, mb_b, myRow, RSRC, npRow )
        ibcol   = indxg2p( jb, nb_b, myCol, CSRC, npCol )
        Mpb0    = numroc( m+iroffb, mb_b, myRow, ibrow, npRow )
        Npb0    = numroc( n+iroffb, mb_b, myRow, ibrow, npRow )
        NRHSqb0 = numroc( DESCB(N_)+icoffb, nb_b, myCol, ibcol, npCol )

        ltau    = numroc( ja+min(m,n)-1, nb_a, myCol, CSRC, npCol )
        lwf     = nb_a * ( Mpa0 + Nqa0 + nb_a )
        lws     = max( (nb_a*(nb_a-1))/2, (NRHSqb0 + Mpb0)*nb_a ) + &
                    nb_a * nb_a

        lWork   = ltau + max ( lwf, lws )


        ! Least squares or LU decomp for square array
        ! -------------------------------------------

        if(square) then 

            if(iAm==0) write(*,*) &
            "   using LU decomposition for square system"

            allocate ( ipiv ( numroc ( m, mb_a, myRow, RSRC, npRow ) + mb_a ) )
            ipiv = 0

#ifdef USE_ROW_SCALING
             if (use_row_scaling) then
               if(iAm==0)write(*,*) '		Using row scaling'
               call start_timer( tRowScale )

               do i=1,n
                 iia = (ia-1) + i
                 incx = DESCA(M_)
                 call pdznrm2( n,rnorm,A,iia,ja,DESCA, incx )

                 rnorm_inv = 1.0
                 if (abs(rnorm) .gt. epsilon(rnorm)) then
                     rnorm_inv = 1.0/rnorm
                 endif
                 call pzdscal(n, rnorm_inv, A,iia,ja,DESCA,incx)

                 incx = DESCB(M_)
                 iib = (ib-1) + i
                 call pzdscal(DESCB(N_),rnorm_inv, B,iib,jb,DESCB,incx)
                enddo

                if (iAm == 0) then
                  write(*,*) 'Row Scaling took ', end_timer( tRowScale )
                endif
               endif

               if (use_column_scaling) then
                 if(iAm==0)write(*,*) '		Using col scaling'
                 allocate( cnorm_inv_array(n) )
                 do j=1,n
                   jja = (ja-1) + j
                   incx = 1
                   call pdznrm2(n,cnorm,A,ia,jja,DESCA,incx)

                   cnorm_inv = 1.0
                   if (abs(cnorm) .gt. epsilon(cnorm)) then
                       cnorm_inv = 1.0/cnorm
                   endif
                   cnorm_inv_array(j) = cnorm_inv

                   incx = 1
                   call pzdscal(n,cnorm_inv, A,ia,jja,DESCA,incx)
                  enddo
                 endif
#endif

#ifdef USE_RCOND
! -------------------------------------------
! compute norm(A) needed later in estimating
! condition number
! -------------------------------------------
             TimeRCond = 0
             call start_timer(tRCond)
             lrwork = 2*n
             allocate(rwork(lrwork))
             anorm = pzlange(norm,n,n,A,ia,ja,DESCA,rwork)
             deallocate(rwork)
             TimeRCond = end_timer(tRCond)
#endif

#ifndef USE_GPU

#ifndef dblprec
            call pcgesv ( n, DESCB(N_), A, ia, ja, DESCA, ipiv, &
                    B, ib, jb, DESCB, info ) 
#else
#ifdef USE_PGESVR
            if(iAm==0)write(*,*) '		Using iterative refinement PZGESVR'
            call start_timer(tSolve0)
            call pzgesvr ( n, DESCB(N_), A, ia, ja, DESCA, ipiv, &
                    B, ib, jb, DESCB, info ) 
            if(iAm==0)write(*,*) '    Time to solve (0): ', end_timer(tSolve0)
#else
            if(iAm==0)write(*,*) '		Using regular PZGESV complex*16'
            call start_timer(tSolve0)
            call pzgesv ( DESCB(M_), DESCB(N_), A, IA, JA, DESCA, ipiv, &
                    B, IB, JB, DESCB, info ) 
            if(info.ne.0)then
                    write(*,*) 'ERROR: PZGESC info = : ', info
                    stop
            endif
            if(iAm==0)write(*,*) '    Time to solve (0): ', end_timer(tSolve0)
#endif
#endif

#else
! use GPU version
! 4 GBytes on  1 MPI task, memsize = 256*1024*1024
! 4 GBytes on  4 MPI tasks, memsize = 64*1024*1024
! 4 GBytes on  8 MPI tasks, memsize = 32*1024*1024
! 4 GBytes on 16 MPI tasks, memsize = 16*1024*1024
!

             memsize = 16*1024*1024
             call getenv("MEMSIZE",memsize_str)
             if (len(trim(memsize_str)).ge.1) then
               ivalue = 32
               read(memsize_str,*,iostat=istatus) ivalue
               if ((istatus.eq.0).and.(ivalue.ge.1)) then
                 memsize = ivalue*1024*1024
               endif
             endif
             if (iAm == 0) then
               write(*,*) 'memsize = ', memsize
             endif


#ifdef USE_PGESVR
            if(iAm==0)write(*,*) '		Using iterative refinement PZGESVR on GPU'
            call start_timer(tSolve0)
            call pzgesvr ( n, DESCB(N_), A, ia, ja, DESCA, ipiv, &
                    B, ib, jb, DESCB, info ) 
            if(iAm==0)write(*,*) '    Time to solve (0): ', end_timer(tSolve0)
#else

!debug       call pzgetrf(n,n,A, ia,ja,DESCA,ipiv,  info)
            if(iAm==0)write(*,*) '		Using OOC PZGESV complex*16 on GPU'
            call start_timer(tSolve0)
            call start_timer(tSolve0_onlyfactor)
            call pzgetrf_ooc2(n,n,A, ia,ja,DESCA,ipiv,  &
                     memsize, info )
            if(iAm==0)write(*,*) '    Time to solve (0 - onlyfactor): ', &
                end_timer(tSolve0_onlyfactor)


             if ((info.ne.0) .and. (iAm == 0)) then
               write(*,*) 'pzgetrf_ooc status: ',info
             endif

            call pzgetrs( 'N',n,DESCB(N_),A,ia,ja,DESCA,ipiv, &
                    B, ib, jb, DESCB, info)
            if(iAm==0)write(*,*) '    Time to solve (0): ', end_timer(tSolve0)

             if ((info.ne.0) .and. (iAm == 0)) then
               write(*,*) 'pzgetrs status: ',info
             endif
#endif



#endif

#ifdef USE_ROW_SCALING
             if (use_column_scaling) then
               do i=1,n
                  iib = (ib-1) + i
                  cnorm_inv = cnorm_inv_array(i)
                  incx = DESCB(M_)
                  call pzdscal( DESCB(N_), cnorm_inv, &
                         B,iib,jb,DESCB,incx)
                enddo
                deallocate( cnorm_inv_array )
              endif
#endif

#ifdef USE_RCOND
             if(iAm==0)write(*,*) '        Estimating rCond'
             call start_timer(tRCond)
             lzwork = -1
             lrwork = -1
             call pzgecon( norm,n, A,ia,ja,DESCA,  &
                  anorm,rcond, zwork1,lzwork,rwork1,lrwork,info)

             lzwork = int(abs(zwork1(1))) + 1
             lrwork = int( abs(rwork1(1)) ) + 1
             allocate( zwork(lzwork), rwork(lrwork) )
             call pzgecon( '1',n, A,ia,ja,DESCA,  &
                  anorm,rcond, zwork,lzwork,rwork,lrwork,info)
             deallocate( zwork, rwork )

             if ((info.ne.0) .and. (iAm == 0)) then
               write(*,*) 'pzgecon status ',info
             endif
             if (iAm == 0) then
               write(*,*) 'estimated rcond = ',rcond
             endif
             TimeRCond = TimeRCond + end_timer(tRCond)
             if(iAm==0)write(*,*) '    Time to estimate RCond: ', TimeRCond

#endif


            if (iAm==0) then 
                write(*,*) '    pcgesv status: ', info
            endif

            deallocate ( ipiv )


          else ! if (square)
            if(iAm==0) write(*,*) &
            "   using least squares for n x m system"

            allocate ( work ( lWork ) )
            work = 0

#ifndef dblprec
            call pcgels ( trans, m, n, DESCB(N_), A, ia, ja, DESCA, &
                        B, ib, jb, DESCB, work, lWork, info ) 
#else
            call pzgels ( trans, m, n, DESCB(N_), A, ia, ja, DESCA, &
                        B, ib, jb, DESCB, work, lWork, info ) 
#endif
            if (iAm==0) then 
                write(*,*) '    pcgels status: ', info
                write(*,*) '    actual/optimal lwork: ', lwork, real(work(1))
            endif

            deallocate ( work )

          endif  ! if (square)
     
        if  (info/=0) then

            write(*,*) 'solve.F90: ERROR, solve did not complete successfully'
            stop

        endif 
        
        call gather_coeffs ()

    end subroutine solve_lsq_parallel


    subroutine gather_coeffs ()

        use aorsaNamelist, &
            only: npRow, npCol
        use antenna, &
            only: B=>brhs, B_global=>brhs_global
        use parallel, only : RSRC, CSRC, &
                MYROW, MYCOL, iAm, ICTXT, NRHS, LM_A, LM_B, LN_A, LN_B, &
                DESCA, DESCB
        use scalapack_mod

        implicit none

        integer :: Li, Lj, Gi, Gj ! (L)ocal and (G)lobal indices

        !   Gather the solution vector from all processors by
        !   creating a global solution vector of the full, not
        !   local size, and have each proc fill in its piece.

        do Li=1,LM_B
            do Lj=1,LN_B

                Gi = IndxL2G ( Li, DESCB(MB_), MyRow, DESCB(RSRC_), NpRow )
                Gj = IndxL2G ( Lj, DESCB(NB_), MyCol, DESCB(CSRC_), NpCol )

                B_global(Gi,Gj) = B(Li,Lj)

            enddo
        enddo

        call cgSum2D(ICTXT,'All',' ',DESCB(M_),DESCB(N_),B_global,DESCB(LLD_),-1,-1)

    end subroutine gather_coeffs

#endif

    subroutine extract_coeffs ( g )

        use grid
        use antenna, &
            only: B_global=>brhs_global
        use parallel, only: NRHS
 
        implicit none

        type(gridBlock), intent(inout) :: g

        integer :: m, n, iCol,rhs

        !   Extract the k coefficents from the solution
        !   for each field component
        !   -------------------------------------------

        allocate ( &
            g%ealphak(g%nMin:g%nMax,g%mMin:g%mMax,NRHS), &
            g%ebetak(g%nMin:g%nMax,g%mMin:g%mMax,NRHS), &
            g%eBk(g%nMin:g%nMax,g%mMin:g%mMax,NRHS) )

        do rhs=1,NRHS
        do n=g%nMin,g%nMax
            do m=g%mMin,g%mMax

                iCol = (m-g%mMin) * 3 + (n-g%nMin) * g%nModesZ * 3 + 1
                iCol = iCol + ( g%StartCol-1 )
       
                g%ealphak(n,m,rhs)    = B_global(iCol+0,rhs)
                g%ebetak(n,m,rhs)     = B_global(iCol+1,rhs)
                g%eBk(n,m,rhs)        = B_global(iCol+2,rhs)

            enddo
        enddo
        enddo ! rhs loop

    end subroutine extract_coeffs

end module solve
