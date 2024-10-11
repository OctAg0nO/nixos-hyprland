{
  pkgs,
  config,
  inputs,
  ...
}: let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];
  users.users.dileep = {
    isNormalUser = true;
    description = "Dileep Kishore";
    shell = pkgs.zsh;
    extraGroups = ["networkmanager" "wheel" "docker" "podman"] ++ ifTheyExist ["libvirtd" "mysql" "network" "git"];
    packages = [pkgs.home-manager];
  };

  # Import this user's personal/home configurations
  home-manager.users.dileep = import ../../../../home/${config.networking.hostName}.nix;

  # Sops secrets
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/dileep/.config/sops/age/keys.txt";
    secrets.OPENAI_API_KEY = {
      owner = config.users.users.dileep.name;
    };
    secrets.ANTHROPIC_API_KEY = {
      owner = config.users.users.dileep.name;
    };
  };

  # 1password
  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = ["dileep"];
    };
  };

  # OpenAI API Key
  systemd.services.aisecret = {
    enable = true;
    description = "API Key";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    script = ''
      mkdir -p /home/dileep/.secrets
      echo $(cat ${config.sops.secrets.OPENAI_API_KEY.path}) > /home/dileep/.secrets/openai_api_key.txt
      echo $(cat ${config.sops.secrets.ANTHROPIC_API_KEY.path}) > /home/dileep/.secrets/anthropic_api_key.txt
    '';
    serviceConfig = {
      User = "dileep";
      WorkingDirectory = "/home/dileep";
    };
  };
  systemd.services.flatpak-repo = {
    enable = true;
    description = "Flathub repo for flatpak";
    wantedBy = ["multi-user.target"];
    path = [pkgs.flatpak];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # vpn
  # TODO: Figure out how to make nordvpn connection more dynamic
  services.openvpn.servers = {
    homeVPN = {config = ''config /home/dileep/.nordvpn/us9565.nordvpn.com.udp.ovpn '';};
  };
}
