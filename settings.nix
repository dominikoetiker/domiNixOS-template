{
  userConfig = {
    username = "username"; # <-- TODO: Change this to your username.
    fullName = "Full Name"; # <-- TODO: Change this to your full name.
    email = "username@example.com"; # <-- TODO: Change this to your email.
    gitCredentialUrls = [
      # <-- TODO: Add any URLs you want to use with Git
      "https://github.com"
      "https://gist.github.com"
    ];
    projectDirs = [
      # <-- TODO: Add any directories you want to use for projects. These will be created in your home directory and accassible via the tmux sessionizer
      "$HOME"
      "$HOME/GitHub"
      "$HOME/Projects"
      "$HOME/TempProjects"
    ];
    theme = "catppuccin-mocha"; # or gruvbox-dark.
  };
  machineConfig = {
    stateVersion = "25.11"; # NOTE: never change this line after the initial installation!
    hostName = "dominixos-btw"; # <-- TODO: Change this to your machine's hostname.
    defaultLocale = "en_US.UTF-8"; # <-- TODO: Chose your default locale. This is used for the system language
    extraLocale = "en_US.UTF-8"; # <-- TODO: Chose your regional locale. This is used for formats of dates, numbers, etc.
    timeZone = "America/New_York"; # <-- TODO: Chose your time zone.
    xkb = {
      layout = "us"; # <-- TODO: Chose your keyboard layout.
      variant = "altgr-intl"; # <-- TODO: Chose your keyboard variant. This is used for special characters.
    };
  };
  hardwareConfig = {
    kernelModules = {
      # Chose between `amdgpu` for AMD, `i915` for Intel, `nvidia` for NVIDIA and `virtio-gpu` for Virtual Machines.
      gpu = "amdgpu"; # <-- TODO: Chose your GPU kernel module.
    };
  };
}
