{ config, lib, ... }:

{
  mailserver = {
    enable = true;
    stateVersion = 5;
    fqdn = "mail.selim.one";
    domains = [ "selim.one" "civ6.ch" ];

    # Password files live on the server, not in git.
    # Generate with: nix-shell -p mkpasswd --run 'mkpasswd -s -m bcrypt' > /etc/mailserver/password-selim
    accounts = {
      "selim@selim.one" = {
        hashedPasswordFile = "/etc/mailserver/password-selim";
        aliases = [
          "postmaster@selim.one"
          "postmaster@civ6.ch"
          "abuse@selim.one"
          "abuse@civ6.ch"
        ];
      };
      "no-reply@civ6.ch" = {
        hashedPasswordFile = "/etc/mailserver/password-noreply-civ6";
        sendOnly = true;
      };
    };

    x509.useACMEHost = "mail.selim.one";
  };

  # ACME cert via Cloudflare DNS-01 — no conflict with Caddy on port 80.
  # Needs /etc/secrets/cloudflare-acme.env on the server containing:
  #   CLOUDFLARE_DNS_API_TOKEN=<token with Zone:DNS:Edit for selim.one>
  security.acme = {
    acceptTerms = true;
    defaults.email = "selim@selim.one";
    certs."mail.selim.one" = {
      dnsProvider = "cloudflare";
      environmentFile = "/etc/secrets/cloudflare-acme.env";
    };
  };
}
