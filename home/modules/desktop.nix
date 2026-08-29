{ pkgs, ... }:

let
  wallpaper = ../assets/shirdi-sai-baba-wallpaper-4k.jpg;
in
{
  home.pointerCursor = {
    enable = true;
    package = pkgs.rose-pine-cursor;
    name = "BreezeX-RosePine-Linux";
    size = 28;
    gtk.enable = true;
    x11.enable = true;
  };

  home.packages = with pkgs; [
    rose-pine-hyprcursor
    waypaper
  ];

  home.sessionVariables = {
    XCURSOR_THEME = "BreezeX-RosePine-Linux";
    XCURSOR_SIZE = "28";
    HYPRCURSOR_THEME = "rose-pine-hyprcursor";
    HYPRCURSOR_SIZE = "28";
  };

  gtk.enable = true;

  home.file."Pictures/sai-baba-wallpaper.jpg" = {
    source = wallpaper;
    force = true;
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = true;
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "${wallpaper}";
          fit_mode = "cover";
        }
      ];
    };
  };

  xdg.configFile."waypaper/config.ini" = {
    force = true;
    text = ''
      [Settings]
      language = en
      folder = ~/Pictures
      monitors = All
      wallpaper = ~/Pictures/sai-baba-wallpaper.jpg
      show_path_in_tooltip = True
      backend = hyprpaper
      fill = fill
      sort = name
      color = #202020
      subfolders = False
      all_subfolders = False
      show_hidden = False
      show_gifs_only = False
      zen_mode = False
      post_command =
      number_of_columns = 3
      swww_transition_type = any
      swww_transition_step = 63
      swww_transition_angle = 0
      swww_transition_duration = 2
      swww_transition_fps = 60
      mpvpaper_sound = False
      mpvpaper_options =
      use_xdg_state = False
    '';
  };
}
