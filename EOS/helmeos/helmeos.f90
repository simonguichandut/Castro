module helmeos_module

!..for the tables, in general
      integer          imax,jmax,itmax,jtmax
      parameter        (imax = 271, jmax = 101)
      double precision d(imax),t(jmax)
      
      double precision tlo, thi, tstp, tstpi
      double precision dlo, dhi, dstp, dstpi

!..for the helmholtz free energy tables
      double precision f(imax,jmax),fd(imax,jmax),                     &
                       ft(imax,jmax),fdd(imax,jmax),ftt(imax,jmax),    &
                       fdt(imax,jmax),fddt(imax,jmax),fdtt(imax,jmax), &
                       fddtt(imax,jmax)

!..for the pressure derivative with density ables
      double precision dpdf(imax,jmax),dpdfd(imax,jmax),                &
                       dpdft(imax,jmax),dpdfdt(imax,jmax)

!..for chemical potential tables
      double precision ef(imax,jmax),efd(imax,jmax),                    &
                       eft(imax,jmax),efdt(imax,jmax)

!..for the number density tables
      double precision xf(imax,jmax),xfd(imax,jmax),                    &
                       xft(imax,jmax),xfdt(imax,jmax)

!..for storing the differences
      double precision dt_sav(jmax),dt2_sav(jmax),                      &
                       dti_sav(jmax),dt2i_sav(jmax),                    &
                       dd_sav(imax),dd2_sav(imax),                      &
                       ddi_sav(imax),dd2i_sav(imax)


      integer,          save, private :: max_newton = 100

      double precision, save, private :: ttol = 1.0d-8
      double precision, save, private :: dtol = 1.0d-8

      ! 2006 CODATA physical constants                                                                             

      ! Math constants                                                                                             
      double precision :: pi       = 3.1415926535897932384d0
      double precision :: eulercon = 0.577215664901532861d0
      double precision :: a2rad    
      double precision :: rad2a

      ! Physical constants                                                                                         
      double precision :: g       = 6.6742867d-8
      double precision :: h       = 6.6260689633d-27
      double precision :: hbar    
      double precision :: qe      = 4.8032042712d-10
      double precision :: avo     = 6.0221417930d23
      double precision :: clight  = 2.99792458d10
      double precision :: kerg    = 1.380650424d-16
      double precision :: ev2erg  = 1.60217648740d-12
      double precision :: kev     
      double precision :: amu     = 1.66053878283d-24
      double precision :: mn      = 1.67492721184d-24
      double precision :: mp      = 1.67262163783d-24
      double precision :: me      = 9.1093821545d-28
      double precision :: rbohr   
      double precision :: fine    
      double precision :: hion    = 13.605698140d0

      double precision :: ssol    = 5.67051d-5
      double precision :: asol
      double precision :: weinlam
      double precision :: weinfre 
      double precision :: rhonuc  = 2.342d14

      ! Astronomical constants                                                                                     
      double precision :: msol    = 1.9892d33
      double precision :: rsol    = 6.95997d10
      double precision :: lsol    = 3.8268d33
      double precision :: mearth  = 5.9764d27
      double precision :: rearth  = 6.37d8
      double precision :: ly      = 9.460528d17
      double precision :: pc
      double precision :: au      = 1.495978921d13
      double precision :: secyer  = 3.1558149984d7

      ! Some other useful combinations of the constants
      double precision :: sioncon
      double precision :: forth  
      double precision :: forpi  
      double precision :: kergavo
      double precision :: ikavo  
      double precision :: asoli3 
      double precision :: light2

      ! Constants used for the Coulomb corrections
      double precision :: a1    = -0.898004d0
      double precision :: b1    =  0.96786d0
      double precision :: c1    =  0.220703d0
      double precision :: d1    = -0.86097d0
      double precision :: e1    =  2.5269d0
      double precision :: a2    =  0.29561d0
      double precision :: b2    =  1.9885d0
      double precision :: c2    =  0.288675d0
      double precision :: onethird = 1.0d0/3.0d0
      double precision :: esqu

contains

      subroutine helmeos(do_coulomb, eosfail, state, N, input)

      use bl_error_module
      use bl_types
      use bl_constants_module
      use eos_type_module
      use eos_data_module

      implicit none

!  Frank Timmes Helmholtz based Equation of State
!  http://cococubed.asu.edu/


!..given a temperature temp [K], density den [g/cm**3], and a composition 
!..characterized by abar and zbar, this routine returns most of the other 
!..thermodynamic quantities. of prime interest is the pressure [erg/cm**3], 
!..specific thermal energy [erg/gr], the entropy [erg/g/K], along with 
!..their derivatives with respect to temperature, density, abar, and zbar.
!..other quantites such the normalized chemical potential eta (plus its
!..derivatives), number density of electrons and positron pair (along 
!..with their derivatives), adiabatic indices, specific heats, and 
!..relativistically correct sound speed are also returned.
!..
!..this routine assumes planckian photons, an ideal gas of ions,
!..and an electron-positron gas with an arbitrary degree of relativity
!..and degeneracy. interpolation in a table of the helmholtz free energy
!..is used to return the electron-positron thermodynamic quantities.
!..all other derivatives are analytic.
!..
!..references: cox & giuli chapter 24 ; timmes & swesty apj 1999

!..input arguments
      logical :: do_coulomb, eosfail
      integer :: N
      type (eos_t), dimension(N) :: state
      integer :: input

!..outputs
      double precision temp_row(N), den_row(N), abar_row(N), &
                       zbar_row(N), etot_row(N), ptot_row(N), &
                       cv_row(N), cp_row(N),  &
                       xne_row(N), xnp_row(N), etaele_row(N), &
                       pele_row(N), ppos_row(N), dpd_row(N),  &
                       dpt_row(N), dpa_row(N), dpz_row(N),  &
                       ded_row(N), det_row(N), dea_row(N),  &
                       dez_row(N),  &
                       stot_row(N), dsd_row(N), dst_row(N), &
                       htot_row(N), dhd_row(N), dht_row(N), &
                       dpe_row(N), dpdr_e_row(N)
      double precision gam1_row(N), cs_row(N)

! these directives are used by f2py to generate a python wrapper around this
! fortran code
!
!f2py intent(in)    :: do_coulomb
!f2py intent(out)   :: eosfail
!f2py intent(inout) :: state

!..declare local variables

      integer j

      logical :: single_iter, double_iter, converged
      integer :: var, dvar, var1, var2, dvar1, dvar2, iter
      double precision :: v_want(N), v1_want(N), v2_want(N)
      double precision :: xnew, xtol, dvdx, smallx, error, v
      double precision :: v1, v2, dv1dt, dv1dr, dv2dt,dv2dr, delr, error1, error2, told, rold, tnew, rnew, v1i, v2i

      double precision x,y,zz,zzi,deni,tempi,xni,dxnidd,dxnida, &
                       dpepdt,dpepdd,deepdt,deepdd,dsepdd,dsepdt, &
                       dpraddd,dpraddt,deraddd,deraddt,dpiondd,dpiondt, &
                       deiondd,deiondt,dsraddd,dsraddt,dsiondd,dsiondt, &
                       dse,dpe,dsp,kt,ktinv,prad,erad,srad,pion,eion, &
                       sion,xnem,pele,eele,sele,pres,ener,entr,dpresdd, &
                       dpresdt,denerdd,denerdt,dentrdd,dentrdt,cv,cp, &
                       gam1,gam2,gam3,chit,chid,nabad,sound,etaele, &
                       detadt,detadd,xnefer,dxnedt,dxnedd,s, &
                       temp,den,abar,zbar,ytot1,ye

!..for the abar derivatives
      double precision dpradda,deradda,dsradda, &
                       dpionda,deionda,dsionda, &
                       dpepda,deepda,dsepda,    &
                       dpresda,denerda,dentrda, &
                       detada,dxneda


!..for the zbar derivatives
      double precision dpraddz,deraddz,dsraddz, &
                       dpiondz,deiondz,dsiondz, &
                       dpepdz,deepdz,dsepdz,    &
                       dpresdz,denerdz,dentrdz ,&
                       detadz,dxnedz



!..for the interpolations
      integer          iat,jat
      double precision free,df_d,df_t,df_tt,df_dt
      double precision xt,xd,mxt,mxd, &
                       si0t,si1t,si2t,si0mt,si1mt,si2mt, &
                       si0d,si1d,si2d,si0md,si1md,si2md, &
                       dsi0t,dsi1t,dsi2t,dsi0mt,dsi1mt,dsi2mt, &
                       dsi0d,dsi1d,dsi2d,dsi0md,dsi1md,dsi2md, &
                       ddsi0t,ddsi1t,ddsi2t,ddsi0mt,ddsi1mt,ddsi2mt, &
                       z,psi0,dpsi0,ddpsi0,psi1,dpsi1,ddpsi1,psi2, &
                       dpsi2,ddpsi2,din,h5,fi(36), &
                       xpsi0,xdpsi0,xpsi1,xdpsi1,h3, &
                       w0t,w1t,w2t,w0mt,w1mt,w2mt, &
                       w0d,w1d,w2d,w0md,w1md,w2md

!..for the coulomb corrections
      double precision dsdd,dsda,lami,inv_lami,lamida,lamidd,     &
                       plasg,plasgdd,plasgdt,plasgda,plasgdz,     &
                       ecoul,decouldd,decouldt,decoulda,decouldz, &
                       pcoul,dpcouldd,dpcouldt,dpcoulda,dpcouldz, &
                       scoul,dscouldd,dscouldt,dscoulda,dscouldz

! ======================================================================
!..Define Statement Functions

!..quintic hermite polynomial statement functions
!..psi0 and its derivatives
!      psi0(z)   = z**3 * ( z * (-6.0d0*z + 15.0d0) -10.0d0) + 1.0d0
      psi0(z)   = z*z*z * ( z * (-6.0d0*z + 15.0d0) -10.0d0) + 1.0d0
!      dpsi0(z)  = z**2 * ( z * (-30.0d0*z + 60.0d0) - 30.0d0)
      dpsi0(z)  = z*z * ( z * (-30.0d0*z + 60.0d0) - 30.0d0)
      ddpsi0(z) = z* ( z*( -120.0d0*z + 180.0d0) -60.0d0)

!..psi1 and its derivatives
!      psi1(z)   = z* ( z**2 * ( z * (-3.0d0*z + 8.0d0) - 6.0d0) + 1.0d0)
      psi1(z)   = z* ( z*z * ( z * (-3.0d0*z + 8.0d0) - 6.0d0) + 1.0d0)
      dpsi1(z)  = z*z * ( z * (-15.0d0*z + 32.0d0) - 18.0d0) +1.0d0
      ddpsi1(z) = z * (z * (-60.0d0*z + 96.0d0) -36.0d0)

!..psi2  and its derivatives
      psi2(z)   = 0.5d0*z*z*( z* ( z * (-z + 3.0d0) - 3.0d0) + 1.0d0)
      dpsi2(z)  = 0.5d0*z*( z*(z*(-5.0d0*z + 12.0d0) - 9.0d0) + 2.0d0)
      ddpsi2(z) = 0.5d0*(z*( z * (-20.0d0*z + 36.0d0) - 18.0d0) + 2.0d0)

!..biquintic hermite polynomial statement function
      h5(w0t,w1t,w2t,w0mt,w1mt,w2mt,w0d,w1d,w2d,w0md,w1md,w2md)= &
             fi(1)  *w0d*w0t   + fi(2)  *w0md*w0t &
           + fi(3)  *w0d*w0mt  + fi(4)  *w0md*w0mt &
           + fi(5)  *w0d*w1t   + fi(6)  *w0md*w1t &
           + fi(7)  *w0d*w1mt  + fi(8)  *w0md*w1mt &
           + fi(9)  *w0d*w2t   + fi(10) *w0md*w2t &
           + fi(11) *w0d*w2mt  + fi(12) *w0md*w2mt &
           + fi(13) *w1d*w0t   + fi(14) *w1md*w0t &
           + fi(15) *w1d*w0mt  + fi(16) *w1md*w0mt &
           + fi(17) *w2d*w0t   + fi(18) *w2md*w0t &
           + fi(19) *w2d*w0mt  + fi(20) *w2md*w0mt &
           + fi(21) *w1d*w1t   + fi(22) *w1md*w1t &
           + fi(23) *w1d*w1mt  + fi(24) *w1md*w1mt &
           + fi(25) *w2d*w1t   + fi(26) *w2md*w1t &
           + fi(27) *w2d*w1mt  + fi(28) *w2md*w1mt &
           + fi(29) *w1d*w2t   + fi(30) *w1md*w2t &
           + fi(31) *w1d*w2mt  + fi(32) *w1md*w2mt &
           + fi(33) *w2d*w2t   + fi(34) *w2md*w2t &
           + fi(35) *w2d*w2mt  + fi(36) *w2md*w2mt



!..cubic hermite polynomial statement functions
!..psi0 & derivatives
      xpsi0(z)  = z * z * (2.0d0*z - 3.0d0) + 1.0
      xdpsi0(z) = z * (6.0d0*z - 6.0d0)

!..psi1 & derivatives
      xpsi1(z)  = z * ( z * (z - 2.0d0) + 1.0d0)
      xdpsi1(z) = z * (3.0d0*z - 4.0d0) + 1.0d0


!..bicubic hermite polynomial statement function
      h3(w0t,w1t,w0mt,w1mt,w0d,w1d,w0md,w1md) =  &
             fi(1)  *w0d*w0t   +  fi(2)  *w0md*w0t  &
           + fi(3)  *w0d*w0mt  +  fi(4)  *w0md*w0mt &
           + fi(5)  *w0d*w1t   +  fi(6)  *w0md*w1t  &
           + fi(7)  *w0d*w1mt  +  fi(8)  *w0md*w1mt &
           + fi(9)  *w1d*w0t   +  fi(10) *w1md*w0t  &
           + fi(11) *w1d*w0mt  +  fi(12) *w1md*w0mt &
           + fi(13) *w1d*w1t   +  fi(14) *w1md*w1t  &
           + fi(15) *w1d*w1mt  +  fi(16) *w1md*w1mt

      temp_row = state(:) % T
      den_row  = state(:) % rho
      abar_row = state(:) % abar
      zbar_row = state(:) % zbar

      ! So initial setup for iterations

      if (input .eq. eos_input_rt) then

        ! Nothing to do here.

      elseif (input .eq. eos_input_rh) then

        single_iter = .true.
        v_want(:) = state(:) % h
        var  = ienth
        dvar = itemp

      elseif (input .eq. eos_input_tp) then

        single_iter = .true.
        v_want(:) = state(:) % p
        var  = ipres
        dvar = idens

      elseif (input .eq. eos_input_rp) then

        single_iter = .true.
        v_want(:) = state(:) % p
        var  = ipres
        dvar = itemp

      elseif (input .eq. eos_input_re) then

        single_iter = .true.
        v_want(:) = state(:) % e
        var  = iener
        dvar = itemp

      elseif (input .eq. eos_input_ps) then

        double_iter = .true.
        v1_want(:) = state(:) % p
        v2_want(:) = state(:) % s
        var1 = ipres
        var2 = ientr

      elseif (input .eq. eos_input_ph) then

        double_iter = .true.
        v1_want(:) = state(:) % p
        v1_want(:) = state(:) % h
        var1 = ipres
        var2 = ienth

      elseif (input .eq. eos_input_th) then

        single_iter = .true.
        v_want(:) = state(:) % h
        var  = ienth
        dvar = idens

      endif

!..start of vectorization loop, normal execution starts here

      do j = 1, N

         converged = .false.
         if (input .eq. eos_input_rt) converged = .true.

         do iter = 1, max_newton

            temp  = temp_row(j)
            den   =  den_row(j)
            abar  = abar_row(j)
            zbar  = zbar_row(j)

            ytot1 = 1.0d0 / abar
            ye    = ytot1 * zbar
            din   = ye * den

            !..initialize
            deni    = 1.0d0/den
            tempi   = 1.0d0/temp 
            kt      = kerg * temp
            ktinv   = 1.0d0/kt

            !..radiation section:
            prad    = asoli3 * temp * temp * temp * temp
            dpraddd = 0.0d0
            dpraddt = 4.0d0 * prad*tempi
            dpradda = 0.0d0
            dpraddz = 0.0d0

            erad    = 3.0d0 * prad*deni
            deraddd = -erad*deni
            deraddt = 3.0d0 * dpraddt*deni
            deradda = 0.0d0
            deraddz = 0.0d0

            srad    = (prad*deni + erad)*tempi
            dsraddd = (dpraddd*deni - prad*deni*deni + deraddd)*tempi
            dsraddt = (dpraddt*deni + deraddt - srad)*tempi
            dsradda = 0.0d0
            dsraddz = 0.0d0

            !..ion section:
            xni     = avo * ytot1 * den
            dxnidd  = avo * ytot1
            dxnida  = -xni * ytot1

            pion    = xni * kt
            dpiondd = dxnidd * kt
            dpiondt = xni * kerg
            dpionda = dxnida * kt 
            dpiondz = 0.0d0

            eion    = 1.5d0 * pion*deni
            deiondd = (1.5d0 * dpiondd - eion)*deni
            deiondt = 1.5d0 * dpiondt*deni
            deionda = 1.5d0 * dpionda*deni
            deiondz = 0.0d0

            x       = abar*abar*sqrt(abar) * deni/avo
            s       = sioncon * temp
            z       = x * s * sqrt(s)
            y       = log(z)
            sion    = (pion*deni + eion)*tempi + kergavo * ytot1 * y
            dsiondd = (dpiondd*deni - pion*deni*deni + deiondd)*tempi &
                       - kergavo * deni * ytot1
            dsiondt = (dpiondt*deni + deiondt)*tempi -  &
                      (pion*deni + eion) * tempi*tempi  &
                      + 1.5d0 * kergavo * tempi*ytot1
            x       = avo*kerg/abar
            dsionda = (dpionda*deni + deionda)*tempi  &
                      + kergavo*ytot1*ytot1* (2.5d0 - y)
            dsiondz = 0.0d0

            !..electron-positron section:
            !..assume complete ionization 
            xnem    = xni * zbar

            !..enter the table with ye*den
            din = ye*den

            !..hash locate this temperature and density
            jat = int((log10(temp) - tlo)*tstpi) + 1
            jat = max(1,min(jat,jmax-1))
            iat = int((log10(din) - dlo)*dstpi) + 1
            iat = max(1,min(iat,imax-1))

            !..access the table locations only once
            fi(1)  = f(iat,jat)
            fi(2)  = f(iat+1,jat)
            fi(3)  = f(iat,jat+1)
            fi(4)  = f(iat+1,jat+1)
            fi(5)  = ft(iat,jat)
            fi(6)  = ft(iat+1,jat)
            fi(7)  = ft(iat,jat+1)
            fi(8)  = ft(iat+1,jat+1)
            fi(9)  = ftt(iat,jat)
            fi(10) = ftt(iat+1,jat)
            fi(11) = ftt(iat,jat+1)
            fi(12) = ftt(iat+1,jat+1)
            fi(13) = fd(iat,jat)
            fi(14) = fd(iat+1,jat)
            fi(15) = fd(iat,jat+1)
            fi(16) = fd(iat+1,jat+1)
            fi(17) = fdd(iat,jat)
            fi(18) = fdd(iat+1,jat)
            fi(19) = fdd(iat,jat+1)
            fi(20) = fdd(iat+1,jat+1)
            fi(21) = fdt(iat,jat)
            fi(22) = fdt(iat+1,jat)
            fi(23) = fdt(iat,jat+1)
            fi(24) = fdt(iat+1,jat+1)
            fi(25) = fddt(iat,jat)
            fi(26) = fddt(iat+1,jat)
            fi(27) = fddt(iat,jat+1)
            fi(28) = fddt(iat+1,jat+1)
            fi(29) = fdtt(iat,jat)
            fi(30) = fdtt(iat+1,jat)
            fi(31) = fdtt(iat,jat+1)
            fi(32) = fdtt(iat+1,jat+1)
            fi(33) = fddtt(iat,jat)
            fi(34) = fddtt(iat+1,jat)
            fi(35) = fddtt(iat,jat+1)
            fi(36) = fddtt(iat+1,jat+1)

            !..various differences
            xt  = max( (temp - t(jat))*dti_sav(jat), 0.0d0)
            xd  = max( (din - d(iat))*ddi_sav(iat), 0.0d0)
            mxt = 1.0d0 - xt
            mxd = 1.0d0 - xd

            !..the six density and six temperature basis functions
            si0t =   psi0(xt)
            si1t =   psi1(xt)*dt_sav(jat)
            si2t =   psi2(xt)*dt2_sav(jat)

            si0mt =  psi0(mxt)
            si1mt = -psi1(mxt)*dt_sav(jat)
            si2mt =  psi2(mxt)*dt2_sav(jat)

            si0d =   psi0(xd)
            si1d =   psi1(xd)*dd_sav(iat)
            si2d =   psi2(xd)*dd2_sav(iat)

            si0md =  psi0(mxd)
            si1md = -psi1(mxd)*dd_sav(iat)
            si2md =  psi2(mxd)*dd2_sav(iat)

            !..derivatives of the weight functions
            dsi0t =   dpsi0(xt)*dti_sav(jat)
            dsi1t =   dpsi1(xt)
            dsi2t =   dpsi2(xt)*dt_sav(jat)

            dsi0mt = -dpsi0(mxt)*dti_sav(jat)
            dsi1mt =  dpsi1(mxt)
            dsi2mt = -dpsi2(mxt)*dt_sav(jat)

            dsi0d =   dpsi0(xd)*ddi_sav(iat)
            dsi1d =   dpsi1(xd)
            dsi2d =   dpsi2(xd)*dd_sav(iat)

            dsi0md = -dpsi0(mxd)*ddi_sav(iat)
            dsi1md =  dpsi1(mxd)
            dsi2md = -dpsi2(mxd)*dd_sav(iat)

            !..second derivatives of the weight functions
            ddsi0t =   ddpsi0(xt)*dt2i_sav(jat)
            ddsi1t =   ddpsi1(xt)*dti_sav(jat)
            ddsi2t =   ddpsi2(xt)

            ddsi0mt =  ddpsi0(mxt)*dt2i_sav(jat)
            ddsi1mt = -ddpsi1(mxt)*dti_sav(jat)
            ddsi2mt =  ddpsi2(mxt)

      !     ddsi0d =   ddpsi0(xd)*dd2i_sav(iat)
      !     ddsi1d =   ddpsi1(xd)*ddi_sav(iat)
      !     ddsi2d =   ddpsi2(xd)

      !     ddsi0md =  ddpsi0(mxd)*dd2i_sav(iat)
      !     ddsi1md = -ddpsi1(mxd)*ddi_sav(iat)
      !     ddsi2md =  ddpsi2(mxd)


            !..the free energy
            free  = h5( &
                     si0t,   si1t,   si2t,   si0mt,   si1mt,   si2mt, &
                     si0d,   si1d,   si2d,   si0md,   si1md,   si2md)

            !..derivative with respect to density
            df_d  = h5( &
                     si0t,   si1t,   si2t,   si0mt,   si1mt,   si2mt, &
                     dsi0d,  dsi1d,  dsi2d,  dsi0md,  dsi1md,  dsi2md)

            !..derivative with respect to temperature
            df_t = h5( &
                     dsi0t,  dsi1t,  dsi2t,  dsi0mt,  dsi1mt,  dsi2mt, &
                     si0d,   si1d,   si2d,   si0md,   si1md,   si2md)

            !..derivative with respect to density**2
      !     df_dd = h5( &
      !               si0t,   si1t,   si2t,   si0mt,   si1mt,   si2mt, &
      !               ddsi0d, ddsi1d, ddsi2d, ddsi0md, ddsi1md, ddsi2md)

            !..derivative with respect to temperature**2
            df_tt = h5( &
                   ddsi0t, ddsi1t, ddsi2t, ddsi0mt, ddsi1mt, ddsi2mt, &
                     si0d,   si1d,   si2d,   si0md,   si1md,   si2md)

            !..derivative with respect to temperature and density
            df_dt = h5( &
                     dsi0t,  dsi1t,  dsi2t,  dsi0mt,  dsi1mt,  dsi2mt, &
                     dsi0d,  dsi1d,  dsi2d,  dsi0md,  dsi1md,  dsi2md)

            !..now get the pressure derivative with density, chemical potential, and 
            !..electron positron number densities
            !..get the interpolation weight functions
            si0t   =  xpsi0(xt)
            si1t   =  xpsi1(xt)*dt_sav(jat)

            si0mt  =  xpsi0(mxt)
            si1mt  =  -xpsi1(mxt)*dt_sav(jat)

            si0d   =  xpsi0(xd)
            si1d   =  xpsi1(xd)*dd_sav(iat)

            si0md  =  xpsi0(mxd)
            si1md  =  -xpsi1(mxd)*dd_sav(iat)

            !..derivatives of weight functions
            dsi0t  = xdpsi0(xt)*dti_sav(jat)
            dsi1t  = xdpsi1(xt)

            dsi0mt = -xdpsi0(mxt)*dti_sav(jat)
            dsi1mt = xdpsi1(mxt)

            dsi0d  = xdpsi0(xd)*ddi_sav(iat)
            dsi1d  = xdpsi1(xd)

            dsi0md = -xdpsi0(mxd)*ddi_sav(iat)
            dsi1md = xdpsi1(mxd)

            !..look in the pressure derivative only once
            fi(1)  = dpdf(iat,jat)
            fi(2)  = dpdf(iat+1,jat)
            fi(3)  = dpdf(iat,jat+1)
            fi(4)  = dpdf(iat+1,jat+1)
            fi(5)  = dpdft(iat,jat)
            fi(6)  = dpdft(iat+1,jat)
            fi(7)  = dpdft(iat,jat+1)
            fi(8)  = dpdft(iat+1,jat+1)
            fi(9)  = dpdfd(iat,jat)
            fi(10) = dpdfd(iat+1,jat)
            fi(11) = dpdfd(iat,jat+1)
            fi(12) = dpdfd(iat+1,jat+1)
            fi(13) = dpdfdt(iat,jat)
            fi(14) = dpdfdt(iat+1,jat)
            fi(15) = dpdfdt(iat,jat+1)
            fi(16) = dpdfdt(iat+1,jat+1)

            !..pressure derivative with density
            dpepdd  = h3(   si0t,   si1t,   si0mt,   si1mt, &
                            si0d,   si1d,   si0md,   si1md)
            dpepdd  = max(ye * dpepdd,0.0d0)

            !..look in the electron chemical potential table only once
            fi(1)  = ef(iat,jat)
            fi(2)  = ef(iat+1,jat)
            fi(3)  = ef(iat,jat+1)
            fi(4)  = ef(iat+1,jat+1)
            fi(5)  = eft(iat,jat)
            fi(6)  = eft(iat+1,jat)
            fi(7)  = eft(iat,jat+1)
            fi(8)  = eft(iat+1,jat+1)
            fi(9)  = efd(iat,jat)
            fi(10) = efd(iat+1,jat)
            fi(11) = efd(iat,jat+1)
            fi(12) = efd(iat+1,jat+1)
            fi(13) = efdt(iat,jat)
            fi(14) = efdt(iat+1,jat)
            fi(15) = efdt(iat,jat+1)
            fi(16) = efdt(iat+1,jat+1)

            !..electron chemical potential etaele
            etaele  = h3( si0t,   si1t,   si0mt,   si1mt, &
                          si0d,   si1d,   si0md,   si1md)

            !..derivative with respect to density
            x       = h3( si0t,   si1t,   si0mt,   si1mt, &
                          dsi0d,  dsi1d,  dsi0md,  dsi1md)
            detadd  = ye * x

            !..derivative with respect to temperature
            detadt  = h3( dsi0t,  dsi1t,  dsi0mt,  dsi1mt, &
                          si0d,   si1d,   si0md,   si1md)

            !..derivative with respect to abar and zbar
            detada = -x * din * ytot1
            detadz =  x * den * ytot1

            !..look in the number density table only once
            fi(1)  = xf(iat,jat)
            fi(2)  = xf(iat+1,jat)
            fi(3)  = xf(iat,jat+1)
            fi(4)  = xf(iat+1,jat+1)
            fi(5)  = xft(iat,jat)
            fi(6)  = xft(iat+1,jat)
            fi(7)  = xft(iat,jat+1)
            fi(8)  = xft(iat+1,jat+1)
            fi(9)  = xfd(iat,jat)
            fi(10) = xfd(iat+1,jat)
            fi(11) = xfd(iat,jat+1)
            fi(12) = xfd(iat+1,jat+1)
            fi(13) = xfdt(iat,jat)
            fi(14) = xfdt(iat+1,jat)
            fi(15) = xfdt(iat,jat+1)
            fi(16) = xfdt(iat+1,jat+1)

            !..electron + positron number densities
            xnefer   = h3( si0t,   si1t,   si0mt,   si1mt, &
                           si0d,   si1d,   si0md,   si1md)

            !..derivative with respect to density
            x        = h3( si0t,   si1t,   si0mt,   si1mt, &
                           dsi0d,  dsi1d,  dsi0md,  dsi1md)
            x = max(x,0.0d0)
            dxnedd   = ye * x

            !..derivative with respect to temperature
            dxnedt   = h3( dsi0t,  dsi1t,  dsi0mt,  dsi1mt, &
                           si0d,   si1d,   si0md,   si1md)

            !..derivative with respect to abar and zbar
            dxneda = -x * din * ytot1
            dxnedz =  x  * den * ytot1

            !..the desired electron-positron thermodynamic quantities

            !..dpepdd at high temperatures and low densities is below the
            !..floating point limit of the subtraction of two large terms.
            !..since dpresdd doesn't enter the maxwell relations at all, use the
            !..bicubic interpolation done above instead of this one
            x       = din * din
            pele    = x * df_d
            dpepdt  = x * df_dt
      !     dpepdd  = ye * (x * df_dd + 2.0d0 * din * df_d)
            s       = dpepdd/ye - 2.0d0 * din * df_d
            dpepda  = -ytot1 * (2.0d0 * pele + s * din)
            dpepdz  = den*ytot1*(2.0d0 * din * df_d  +  s)

            x       = ye * ye
            sele    = -df_t * ye
            dsepdt  = -df_tt * ye
            dsepdd  = -df_dt * x
            dsepda  = ytot1 * (ye * df_dt * din - sele)
            dsepdz  = -ytot1 * (ye * df_dt * den  + df_t)

            eele    = ye*free + temp * sele
            deepdt  = temp * dsepdt
            deepdd  = x * df_d + temp * dsepdd
            deepda  = -ye * ytot1 * (free +  df_d * din) + temp * dsepda
            deepdz  = ytot1* (free + ye * df_d * den) + temp * dsepdz

            !..coulomb section:
            !..initialize
            pcoul    = 0.0d0
            dpcouldd = 0.0d0
            dpcouldt = 0.0d0
            dpcoulda = 0.0d0
            dpcouldz = 0.0d0
            ecoul    = 0.0d0
            decouldd = 0.0d0
            decouldt = 0.0d0
            decoulda = 0.0d0
            decouldz = 0.0d0
            scoul    = 0.0d0
            dscouldd = 0.0d0
            dscouldt = 0.0d0
            dscoulda = 0.0d0
            dscouldz = 0.0d0

            !..uniform background corrections only 
            !..from yakovlev & shalybkov 1989 
            !..lami is the average ion seperation
            !..plasg is the plasma coupling parameter
            z        = forth * pi
            s        = z * xni
            dsdd     = z * dxnidd
            dsda     = z * dxnida

            lami     = 1.0d0/s**onethird
            inv_lami = 1.0d0/lami
            z        = -onethird * lami
            lamidd   = z * dsdd/s
            lamida   = z * dsda/s

            plasg    = zbar*zbar*esqu*ktinv*inv_lami
            z        = -plasg * inv_lami 
            plasgdd  = z * lamidd
            plasgda  = z * lamida
            plasgdt  = -plasg*ktinv * kerg
            plasgdz  = 2.0d0 * plasg/zbar

      !     TURN ON/OFF COULOMB
            if ( do_coulomb ) then
                !...yakovlev & shalybkov 1989 equations 82, 85, 86, 87
                if (plasg .ge. 1.0D0) then
                   x        = plasg**(0.25d0) 
                   y        = avo * ytot1 * kerg 
                   ecoul    = y * temp * (a1*plasg + b1*x + c1/x + d1)
                   pcoul    = onethird * den * ecoul
                   scoul    = -y * (3.0d0*b1*x - 5.0d0*c1/x &
                        + d1 * (log(plasg) - 1.0d0) - e1)

                   y        = avo*ytot1*kt*(a1 + 0.25d0/plasg*(b1*x - c1/x))
                   decouldd = y * plasgdd 
                   decouldt = y * plasgdt + ecoul/temp
                   decoulda = y * plasgda - ecoul/abar
                   decouldz = y * plasgdz

                   y        = onethird * den
                   dpcouldd = onethird * ecoul + y*decouldd
                   dpcouldt = y * decouldt
                   dpcoulda = y * decoulda
                   dpcouldz = y * decouldz

                   y        = -avo*kerg/(abar*plasg)* &
                        (0.75d0*b1*x+1.25d0*c1/x+d1)
                   dscouldd = y * plasgdd
                   dscouldt = y * plasgdt
                   dscoulda = y * plasgda - scoul/abar
                   dscouldz = y * plasgdz

                !...yakovlev & shalybkov 1989 equations 102, 103, 104
                else if (plasg .lt. 1.0D0) then
                   x        = plasg*sqrt(plasg)
                   y        = plasg**b2
                   z        = c2 * x - onethird * a2 * y
                   pcoul    = -pion * z
                   ecoul    = 3.0d0 * pcoul/den
                   scoul    = -avo/abar*kerg*(c2*x -a2*(b2-1.0d0)/b2*y)

                   s        = 1.5d0*c2*x/plasg - onethird*a2*b2*y/plasg
                   dpcouldd = -dpiondd*z - pion*s*plasgdd
                   dpcouldt = -dpiondt*z - pion*s*plasgdt
                   dpcoulda = -dpionda*z - pion*s*plasgda
                   dpcouldz = -dpiondz*z - pion*s*plasgdz

                   s        = 3.0d0/den
                   decouldd = s * dpcouldd - ecoul/den
                   decouldt = s * dpcouldt
                   decoulda = s * dpcoulda
                   decouldz = s * dpcouldz

                   s        = -avo*kerg/(abar*plasg)* &
                        (1.5d0*c2*x-a2*(b2-1.0d0)*y)
                   dscouldd = s * plasgdd
                   dscouldt = s * plasgdt
                   dscoulda = s * plasgda - scoul/abar
                   dscouldz = s * plasgdz
                end if

               !...bomb proof
               x   = prad + pion + pele + pcoul
               if (x .le. 0.0D0) then

                  write(6,*) 
                  write(6,*) 'coulomb corr. are causing a negative pressure'
                  write(6,*) 'setting all coulomb corrections to zero'
                  write(6,*) 

                  pcoul    = 0.0d0
                  dpcouldd = 0.0d0
                  dpcouldt = 0.0d0
                  dpcoulda = 0.0d0
                  dpcouldz = 0.0d0
                  ecoul    = 0.0d0
                  decouldd = 0.0d0
                  decouldt = 0.0d0
                  decoulda = 0.0d0
                  decouldz = 0.0d0
                  scoul    = 0.0d0
                  dscouldd = 0.0d0
                  dscouldt = 0.0d0
                  dscoulda = 0.0d0
                  dscouldz = 0.0d0
               end if
            end if
            ! Turn off Coulomb

            !..sum all the components
            pres    = prad + pion + pele + pcoul
            ener    = erad + eion + eele + ecoul
            entr    = srad + sion + sele + scoul

            dpresdd = dpraddd + dpiondd + dpepdd + dpcouldd 
            dpresdt = dpraddt + dpiondt + dpepdt + dpcouldt
            dpresda = dpradda + dpionda + dpepda + dpcoulda
            dpresdz = dpraddz + dpiondz + dpepdz + dpcouldz

            denerdd = deraddd + deiondd + deepdd + decouldd
            denerdt = deraddt + deiondt + deepdt + decouldt
            denerda = deradda + deionda + deepda + decoulda
            denerdz = deraddz + deiondz + deepdz + decouldz

            dentrdd = dsraddd + dsiondd + dsepdd + dscouldd
            dentrdt = dsraddt + dsiondt + dsepdt + dscouldt
            dentrda = dsradda + dsionda + dsepda + dscoulda
            dentrdz = dsraddz + dsiondz + dsepdz + dscouldz

            !..the temperature and density exponents (c&g 9.81 9.82) 
            !..the specific heat at constant volume (c&g 9.92)
            !..the third adiabatic exponent (c&g 9.93)
            !..the first adiabatic exponent (c&g 9.97) 
            !..the second adiabatic exponent (c&g 9.105)
            !..the specific heat at constant pressure (c&g 9.98) 
            !..and relativistic formula for the sound speed (c&g 14.29)
            zz    = pres*deni
            zzi   = den/pres
            chit  = temp/pres * dpresdt
            chid  = dpresdd*zzi
            cv    = denerdt
            x     = zz * chit/(temp * cv)
            gam3  = x + 1.0d0
            gam1  = chit*x + chid
            nabad = x/gam1
            gam2  = 1.0d0/(1.0d0 - nabad)
            cp    = cv * gam1/chid
            z     = 1.0d0 + (ener + light2)*zzi
            sound = clight * sqrt(gam1/z)

            !..maxwell relations; each is zero if the consistency is perfect
            x   = den * den
            dse = temp*dentrdt/denerdt - 1.0d0
            dpe = (denerdd*x + temp*dpresdt)/pres - 1.0d0
            dsp = -dentrdd*x/dpresdt - 1.0d0

            ptot_row(j) = pres
            dpt_row(j) = dpresdt
            dpd_row(j) = dpresdd
            dpe_row(j) = dpresdt / denerdt
            dpdr_e_row(j) = dpresdd - dpresdt * denerdd / denerdt

            etot_row(j) = ener
            det_row(j) = denerdt
            ded_row(j) = denerdd
            dea_row(j) = denerda
            dez_row(j) = denerdz

            stot_row(j) = entr
            dst_row(j) = dentrdt
            dsd_row(j) = dentrdd

            htot_row(j) = ener + pres / den
            dhd_row(j) = dpresdd / den - pres / den**2
            dht_row(j) = denerdt + dpresdt / den

            pele_row(j) = pele
            ppos_row(j) = 0.0d0

            xne_row(j) = xnefer
            xnp_row(j) = 0.0d0

            etaele_row(j) = etaele

            cv_row(j) = cv
            cp_row(j) = cp
            cs_row(j) = sound
            gam1_row(j) = gam1

            if (converged) then

               exit

            elseif (single_iter) then

               if (dvar .eq. itemp) then

                 x = temp_row(j)
                 smallx = smallt
                 xtol = ttol

                 if (var .eq. ipres) then
                   v    = ptot_row(j)
                   dvdx = dpt_row(j)
                 elseif (var .eq. iener) then
                   v    = etot_row(j)
                   dvdx = det_row(j)
                 elseif (var .eq. ientr) then
                   v    = stot_row(j)
                   dvdx = dst_row(j)
                 elseif (var .eq. ienth) then
                   v    = htot_row(j)
                   dvdx = dht_row(j)
                 else
                     exit
                 endif

	       else ! dvar == density                                                                        

                 x = den_row(j)
                 smallx = smalld
                 xtol = dtol                 

                 if (var .eq. ipres) then
                   v    = ptot_row(j)
                   dvdx = dpd_row(j)
                 elseif (var .eq. iener) then
                   v    = etot_row(j)
                   dvdx = ded_row(j)
                 elseif (var .eq. ientr) then
                   v    = stot_row(j)
                   dvdx = dsd_row(j)
                 elseif (var .eq. ienth) then
                   v    = htot_row(j)
                   dvdx = dhd_row(j)
                 else
                   exit
                 endif

               endif

               ! Now do the calculation for the next guess for T/rho                                         

               xnew = x - (v - v_want(j)) / dvdx

	       ! Don't let the temperature/density change by more than a factor of two                       
	       xnew = max(0.5 * x, min(xnew, 2.0 * x))

               ! Don't let us freeze/evacuate                                                                
               xnew = max(smallx, xnew)

	       ! Store the new temperature/density                                                           

               if (dvar .eq. itemp) then
                 temp_row(j) = xnew
               else
                 den_row(j)  = xnew
               endif

               ! Compute the error from the last iteration                                                   

               error = abs( (xnew - x) / x )

               if (error .lt. xtol) converged = .true.

            elseif (double_iter) then

               ! Figure out which variables we're using
 
               told = temp_row(j)
               rold = den_row(j)

               if (var1 .eq. ipres) then
                    v1    = ptot_row(j)
                    dv1dt = dpt_row(j)
                    dv1dr = dpd_row(j)
               elseif (var1 .eq. iener) then
                    v1    = etot_row(j)
                    dv1dt = det_row(j)
                    dv1dr = ded_row(j)
               elseif (var1 .eq. ientr) then
                    v1    = stot_row(j)
                    dv1dt = dst_row(j)
                    dv1dr = dsd_row(j)
               elseif (var1 .eq. ienth) then
                    v1    = htot_row(j)
                    dv1dt = dht_row(j)
                    dv1dr = dhd_row(j)
               else
!                    ierr = ierr_iter_var
                    exit
               endif

               if (var2 .eq. ipres) then
                    v2    = ptot_row(j)
                    dv2dt = dpt_row(j)
                    dv2dr = dpd_row(j)
               elseif (var2 .eq. iener) then
                    v2    = etot_row(j)
                    dv2dt = det_row(j)
                    dv2dr = ded_row(j)
               elseif (var2 .eq. ientr) then
                    v2    = stot_row(j)
                    dv2dt = dst_row(j)
                    dv2dr = dsd_row(j)
               elseif (var2 .eq. ienth) then
                    v2    = htot_row(j)
                    dv2dt = dht_row(j)
                    dv2dr = dhd_row(j)
               else
!                    ierr = ierr_iter_var
                    exit
               endif

               ! Two functions, f and g, to iterate over
               v1i = v1_want(j) - v1
               v1i = v2_want(j) - v2

               !
               ! 0 = f + dfdr * delr + dfdt * delt
               ! 0 = g + dgdr * delr + dgdt * delt
               !

               ! note that dfi/dT = - df/dT
               delr = (-v1i*dv2dt + v2i*dv1dt) / (dv2dr*dv1dt - dv2dt*dv1dr)

               rnew = rold + delr

               tnew = told + (v1i - dv1dr*delr) / dv1dt

               ! Don't let the temperature or density change by more
               ! than a factor of two
               tnew = max(HALF * told, min(tnew, TWO * told))
               rnew = max(HALF * rold, min(rnew, TWO * rold))

               ! Don't let us freeze or evacuate
               tnew = max(smallt, tnew)
               rnew = max(smalld, rnew)

               ! Store the new temperature and density
               den_row(j)  = rnew
               temp_row(j) = tnew

               ! Compute the errors
               error1 = abs( (rnew - rold) / rold )
               error2 = abs( (tnew - told) / told )

               if (error1 .LT. dtol .and. error2 .LT. ttol) converged = .true.

            endif

         enddo

      enddo

      state(:) % p    = ptot_row
      state(:) % dpdT = dpt_row
      state(:) % dpdr = dpd_row
      state(:) % dpdA = dpa_row   
      state(:) % dpdZ = dpz_row
      state(:) % dpde = dpe_row
      state(:) % dpdr_e = dpdr_e_row

      state(:) % e    = etot_row
      state(:) % dedT = det_row
      state(:) % dedr = ded_row
      state(:) % dedA = dea_row   
      state(:) % dedZ = dez_row

      state(:) % s    = stot_row
      state(:) % dsdT = dst_row
      state(:) % dsdr = dsd_row

      state(:) % h    = htot_row
      state(:) % dhdR = dhd_row
      state(:) % dhdT = dht_row

      state(:) % pele = pele_row
      state(:) % ppos = ppos_row

      state(:) % xne = xne_row
      state(:) % xnp = xnp_row

      state(:) % eta = etaele_row

      state(:) % cv   = cv_row
      state(:) % cp   = cp_row
      state(:) % gam1 = gam1_row
      state(:) % cs   = cs_row

      end subroutine helmeos

!     -----------------------------------------------------------------
      subroutine helmeos_init(initialized)

      use bl_error_module

      implicit none
      
      double precision dth, dt2, dti, dt2i
      double precision dd, dd2, ddi, dd2i
      double precision tsav, dsav
      integer i, j

      logical          initialized

      if ( initialized ) return

!..   open the table
      open(unit=2,file='helm_table.dat',status='old',err=1010)
      GO TO 1011
 1010 CONTINUE
      call bl_error('EOSINIT: Failed to open helm_table.dat')
 1011 CONTINUE

      itmax = imax
      jtmax = jmax

!..   read the helmholtz free energy table
      tlo   = 3.0d0
      thi   = 13.0d0
      tstp  = (thi - tlo)/float(jmax-1)
      tstpi = 1.0d0/tstp
      dlo   = -12.0d0
      dhi   = 15.0d0
      dstp  = (dhi - dlo)/float(imax-1)
      dstpi = 1.0d0/dstp
      do j=1,jmax
         tsav = tlo + (j-1)*tstp
         t(j) = 10.0d0**(tsav)
         do i=1,imax
            dsav = dlo + (i-1)*dstp
            d(i) = 10.0d0**(dsav)
            read(2,*) f(i,j),fd(i,j),ft(i,j),fdd(i,j),ftt(i,j),fdt(i,j), &
                 fddt(i,j),fdtt(i,j),fddtt(i,j)
         end do
      end do

!..   read the pressure derivative with density table
      do j = 1, jmax
         do i = 1, imax
            read(2,*) dpdf(i,j),dpdfd(i,j),dpdft(i,j),dpdfdt(i,j)
         end do
      end do

!..   read the electron chemical potential table
      do j = 1, jmax
         do i = 1, imax
            read(2,*) ef(i,j),efd(i,j),eft(i,j),efdt(i,j)
         end do
      end do

!..   read the number density table
      do j = 1, jmax
         do i = 1, imax
            read(2,*) xf(i,j),xfd(i,j),xft(i,j),xfdt(i,j)
         end do
      end do

!..   construct the temperature and density deltas and their inverses 
      do j = 1, jmax-1
         dth         = t(j+1) - t(j)
         dt2         = dth * dth
         dti         = 1.0d0/dth
         dt2i        = 1.0d0/dt2
         dt_sav(j)   = dth
         dt2_sav(j)  = dt2
         dti_sav(j)  = dti
         dt2i_sav(j) = dt2i
      end do
      do i = 1, imax-1
         dd          = d(i+1) - d(i)
         dd2         = dd * dd
         ddi         = 1.0d0/dd
         dd2i        = 1.0d0/dd2
         dd_sav(i)   = dd
         dd2_sav(i)  = dd2
         ddi_sav(i)  = ddi
         dd2i_sav(i) = dd2i
      end do

      close(unit=2)

      ! Some initialization of constants

      esqu = qe * qe

      a2rad   = pi/180.0d0
      rad2a   = 180.0d0/pi

      hbar    = 0.5d0 * h/pi
      kev     = kerg/ev2erg
      rbohr   = hbar*hbar/(me * qe * qe)
      fine    = qe*qe/(hbar*clight)

      asol    = 4.0d0 * ssol / clight
      weinlam = h*clight/(kerg * 4.965114232d0)
      weinfre = 2.821439372d0*kerg/h
      pc      = 3.261633d0 * ly

      sioncon = (2.0d0 * pi * amu * kerg)/(h*h)
      forth   = 4.0d0/3.0d0
      forpi   = 4.0d0 * pi
      kergavo = kerg * avo
      ikavo   = 1.0d0/kergavo
      asoli3  = asol/3.0d0
      light2  = clight * clight

      initialized = .true.
    
      end subroutine helmeos_init

end module helmeos_module
