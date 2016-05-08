! This module stores the runtime parameters and integer names for 
! indexing arrays.
!
! These parameter are initialized in set_method_params() 

module meth_params_module

  implicit none

  integer         , save :: iorder        ! used only in uslope 

  ! number of ghost cells for the hyperbolic solver
  integer, parameter     :: NHYP    = 4

  ! NTHERM: number of thermodynamic variables
  integer         , save :: NTHERM, NVAR
  integer         , save :: URHO, UMX, UMY, UMZ, UMR, UML, UMP, UEDEN, UEINT, UTEMP, UFA, UFS, UFX
  integer         , save :: USHK

  ! QTHERM: number of primitive variables
  integer         , save :: QTHERM, QVAR
  integer         , save :: QRHO, QU, QV, QW, QPRES, QREINT, QTEMP
  integer         , save :: QGAMC, QGAME
  integer         , save :: QFA, QFS, QFX

  ! These are only used when we use the SGS model.
  integer         , save :: UESGS,QESGS

  integer         , save :: nadv

  integer, save :: npassive
  integer, save, allocatable :: qpass_map(:), upass_map(:)

  !$acc declare create(NTHERM, NVAR, URHO, UMX, UMY, UMZ, UMR, UML, UMP)
  !$acc declare create(UEDEN, UEINT, UTEMP, UFA, UFS, UFX, USHK)

  ! These are used for the Godunov state
  ! Note that the velocity indices here are picked to be the same value
  ! as in the primitive variable array
  integer, save :: ngdnv, GDRHO, GDU, GDV, GDW, GDPRES, GDGAME, GDLAMS, GDERADS

  integer         , save :: numpts_1d

  double precision, save, allocatable :: outflow_data_old(:,:)
  double precision, save, allocatable :: outflow_data_new(:,:)
  double precision, save :: outflow_data_old_time
  double precision, save :: outflow_data_new_time
  logical         , save :: outflow_data_allocated
  double precision, save :: max_dist

  double precision, save :: diffuse_cutoff_density

  double precision, save :: const_grav

  logical, save :: get_g_from_phi
  
  character(len=:), allocatable :: gravity_type
  

  double precision, save :: difmag
  double precision, save :: small_dens
  double precision, save :: small_temp
  double precision, save :: small_pres
  double precision, save :: small_ener
  double precision, save :: small_x
  integer         , save :: do_hydro
  integer         , save :: hybrid_hydro
  integer         , save :: ppm_type
  integer         , save :: ppm_reference
  integer         , save :: ppm_trace_sources
  integer         , save :: ppm_temp_fix
  integer         , save :: ppm_tau_in_tracing
  integer         , save :: ppm_predict_gammae
  integer         , save :: ppm_reference_edge_limit
  integer         , save :: ppm_reference_eigenvectors
  integer         , save :: hybrid_riemann
  integer         , save :: use_colglaz
  integer         , save :: riemann_solver
  integer         , save :: cg_maxiter
  double precision, save :: cg_tol
  integer         , save :: cg_blend
  integer         , save :: use_flattening
  integer         , save :: ppm_flatten_before_integrals
  integer         , save :: transverse_use_eos
  integer         , save :: transverse_reset_density
  integer         , save :: transverse_reset_rhoe
  logical         , save :: dual_energy_update_E_from_e
  double precision, save :: dual_energy_eta1
  double precision, save :: dual_energy_eta2
  double precision, save :: dual_energy_eta3
  integer         , save :: use_pslope
  integer         , save :: fix_mass_flux
  integer         , save :: allow_negative_energy
  integer         , save :: allow_small_energy
  integer         , save :: do_sponge
  double precision, save :: cfl
  double precision, save :: dtnuc_e
  double precision, save :: dtnuc_X
  integer         , save :: dtnuc_mode
  double precision, save :: dxnuc
  integer         , save :: do_react
  double precision, save :: react_T_min
  double precision, save :: react_T_max
  double precision, save :: react_rho_min
  double precision, save :: react_rho_max
  integer         , save :: disable_shock_burning
  integer         , save :: do_grav
  integer         , save :: grav_source_type
  integer         , save :: do_rotation
  double precision, save :: rot_period
  double precision, save :: rot_period_dot
  integer         , save :: rotation_include_centrifugal
  integer         , save :: rotation_include_coriolis
  integer         , save :: rotation_include_domegadt
  integer         , save :: rot_source_type
  integer         , save :: implicit_rotation_update
  integer         , save :: rot_axis
  double precision, save :: point_mass
  integer         , save :: point_mass_fix_solution
  integer         , save :: do_acc
  integer         , save :: track_grid_losses

  !$acc declare &
  !$acc create(difmag, small_dens, small_temp) &
  !$acc create(small_pres, small_ener, small_x) &
  !$acc create(do_hydro, hybrid_hydro, ppm_type) &
  !$acc create(ppm_reference, ppm_trace_sources, ppm_temp_fix) &
  !$acc create(ppm_tau_in_tracing, ppm_predict_gammae, ppm_reference_edge_limit) &
  !$acc create(ppm_reference_eigenvectors, hybrid_riemann, use_colglaz) &
  !$acc create(riemann_solver, cg_maxiter, cg_tol) &
  !$acc create(cg_blend, use_flattening, ppm_flatten_before_integrals) &
  !$acc create(transverse_use_eos, transverse_reset_density, transverse_reset_rhoe) &
  !$acc create(dual_energy_update_E_from_e, dual_energy_eta1, dual_energy_eta2) &
  !$acc create(dual_energy_eta3, use_pslope, fix_mass_flux) &
  !$acc create(allow_negative_energy, allow_small_energy, do_sponge) &
  !$acc create(cfl, dtnuc_e, dtnuc_X) &
  !$acc create(dtnuc_mode, dxnuc, do_react) &
  !$acc create(react_T_min, react_T_max, react_rho_min) &
  !$acc create(react_rho_max, disable_shock_burning, do_grav) &
  !$acc create(grav_source_type, do_rotation, rot_period) &
  !$acc create(rot_period_dot, rotation_include_centrifugal, rotation_include_coriolis) &
  !$acc create(rotation_include_domegadt, rot_source_type, implicit_rotation_update) &
  !$acc create(rot_axis, point_mass, point_mass_fix_solution) &
  !$acc create(do_acc, track_grid_losses)

  double precision, save :: rot_vec(3)

end module meth_params_module
