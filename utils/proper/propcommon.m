% script propcommon
% Variables kept in common (global) storage

%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  global npa            % number of points across beam array
  global OldOPD

  global print_it
% print steps in prop_lens, prop_propagate, prop_psd_errormap, prop_run,
% prop_writemap, and prop_zernikes

  global print_total_intensity
  global prop_phase_offset
  global prop_verbose

  global RayFact        % wavefront switches from planar to spherical
                        % at RayFact * bm.zRay

  global save_state     % save state is on (1) or off (0)
  global save_state_lam % list of wavelengths of saved states (m)
  global statefile      % name of state file

  global pwr            % sum of wavefront^2 from prop_define_entrance

  global do_table       % create lists if 1
  global ActionNum      % list index
  global bmdl           % list of beam diameters at each lens (m)
  global dzl            % list of propagation distances (m)
  global efrl           % list of effective focal ratios after each lens
  global fll            % list of lens focal lengths (m)
  global saml           % list of sampling at each surface (m)
  global snml           % list of surface names (cell array)

% end                   % propcommon
