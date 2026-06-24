{ config, lib, pkgs, ... }:

let
  customCss = pkgs.writeText "roundcube-custom.css" (builtins.readFile ./webmail.css);
in
{
  mailserver = {
    enable = true;
    stateVersion = 5;
    fqdn = "mail.selim.one";
    domains = [ "selim.one" "civ6.ch" ];

    # Password files live on the server, not in git.
    # Generate with: nix-shell -p mkpasswd --run 'mkpasswd -s -m bcrypt' > /etc/mailserver/password-me
    accounts = {
      "me@selim.one" = {
        hashedPasswordFile = "/etc/mailserver/password-me";
        aliases = [
          "selim@selim.one"
          "hello@selim.one"
          "contact@selim.one"
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
    defaults.email = "me@selim.one";
    certs."mail.selim.one" = {
      dnsProvider = "cloudflare";
      environmentFile = "/etc/secrets/cloudflare-acme.env";
    };
  };

  # Roundcube webmail at mail.selim.one
  services.roundcube = {
    enable = true;
    hostName = "mail.selim.one";
    extraConfig = ''
      $config['imap_host'] = 'ssl://mail.selim.one:993';
      $config['smtp_host'] = 'ssl://mail.selim.one:465';
      $config['smtp_user'] = '%u';
      $config['smtp_pass'] = '%p';
      $config['product_name'] = 'Selim Mail';
      $config['custom_stylesheet'] = '/custom.css';
    '';
  };

  # nginx serves Roundcube on localhost only — no SSL, Caddy handles TLS.
  # lib.mkForce overrides the roundcube module's SSL defaults.
  services.nginx = {
    defaultListenAddresses = [ "127.0.0.1" ];
    virtualHosts."mail.selim.one" = {
      enableACME = lib.mkForce false;
      addSSL    = lib.mkForce false;
      forceSSL  = lib.mkForce false;
      onlySSL   = lib.mkForce false;
      listen    = lib.mkForce [{ addr = "127.0.0.1"; port = 8025; ssl = false; }];
      locations."= /custom.css".alias = toString customCss;
    };
  };

  # Caddy proxies HTTPS → nginx for Roundcube.
  # Autoconfig endpoints for mail client autodiscovery.
  services.caddy.virtualHosts."mail.selim.one".extraConfig = ''
    reverse_proxy 127.0.0.1:8080
  '';

  services.caddy.virtualHosts."autoconfig.selim.one".extraConfig = ''
    header Content-Type "application/xml; charset=utf-8"
    respond `<?xml version="1.0" encoding="UTF-8"?>
<clientConfig version="1.1">
  <emailProvider id="selim.one">
    <domain>selim.one</domain>
    <displayName>Selim Mail</displayName>
    <displayShortName>Selim</displayShortName>
    <incomingServer type="imap">
      <hostname>mail.selim.one</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>me@selim.one</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>mail.selim.one</hostname>
      <port>465</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>me@selim.one</username>
    </outgoingServer>
  </emailProvider>
</clientConfig>` 200
  '';

  services.caddy.virtualHosts."autodiscover.selim.one".extraConfig = ''
    header Content-Type "application/xml; charset=utf-8"
    respond `<?xml version="1.0" encoding="UTF-8"?>
<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/responseschema/2006">
  <Response xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a">
    <Account>
      <AccountType>email</AccountType>
      <Action>settings</Action>
      <Protocol>
        <Type>IMAP</Type>
        <Server>mail.selim.one</Server>
        <Port>993</Port>
        <LoginName>me@selim.one</LoginName>
        <SSL>on</SSL>
      </Protocol>
      <Protocol>
        <Type>SMTP</Type>
        <Server>mail.selim.one</Server>
        <Port>465</Port>
        <LoginName>me@selim.one</LoginName>
        <SSL>on</SSL>
      </Protocol>
    </Account>
  </Response>
</Autodiscover>` 200
  '';
}
