# Configuration for the official LDAP Authentication plugin, shaped like nps'
# own `jellyfin_sso_config.nix`: a gomplate template rendered at container
# start, so the bind password is read from /run/secrets rather than baked into
# a store path.
#
# Element order follows the declaration order in the plugin's
# `Config/PluginConfiguration.cs`; .NET's XmlSerializer is happier that way.
{
  bindDn,
  bindPasswordFile,
  userBaseDn,
  loginFilter,
  adminFilter,
  ldapServer,
  ldapPort,
  passwordResetUrl,
}:
''
  <?xml version="1.0" encoding="utf-8"?>
  <PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <LdapUsers />
    <LdapServer>${ldapServer}</LdapServer>
    <LdapPort>${toString ldapPort}</LdapPort>
    <!-- Plaintext LDAP on purpose: this never leaves the `traefik-proxy` podman
         network, and lldap serves no TLS of its own. -->
    <UseSsl>false</UseSsl>
    <UseStartTls>false</UseStartTls>
    <SkipSslVerify>false</SkipSslVerify>
    <LdapBindUser>${bindDn}</LdapBindUser>
    <LdapBindPassword>{{ file.Read "${bindPasswordFile}" }}</LdapBindPassword>
    <LdapBaseDn>${userBaseDn}</LdapBaseDn>
    <LdapSearchFilter>${loginFilter}</LdapSearchFilter>
    <LdapAdminBaseDn></LdapAdminBaseDn>
    <LdapAdminFilter>${adminFilter}</LdapAdminFilter>
    <EnableLdapAdminFilterMemberUid>false</EnableLdapAdminFilterMemberUid>
    <LdapSearchAttributes>uid, cn, mail, displayName</LdapSearchAttributes>
    <LdapClientCertPath></LdapClientCertPath>
    <LdapClientKeyPath></LdapClientKeyPath>
    <LdapRootCaPath></LdapRootCaPath>
    <CreateUsersFromLdap>true</CreateUsersFromLdap>
    <!-- Passwords are changed in lldap's own UI, which is what
         `PasswordResetUrl` points at; letting Jellyfin write them back would
         need a non-readonly bind user. -->
    <AllowPassChange>false</AllowPassChange>
    <LdapUidAttribute>uid</LdapUidAttribute>
    <LdapUsernameAttribute>uid</LdapUsernameAttribute>
    <LdapPasswordAttribute>userPassword</LdapPasswordAttribute>
    <!-- lldap does hold a `jpegPhoto` blob, but the plugin tracks which avatar
         it has already synced in `LdapUsers`, inside this file -- which is
         regenerated on every container start. Enabling the sync would re-fetch
         every avatar each restart, so leave it off until the plugin config is
         stateful. -->
    <EnableLdapProfileImageSync>false</EnableLdapProfileImageSync>
    <RemoveImagesNotInLdap>false</RemoveImagesNotInLdap>
    <LdapProfileImageAttribute>jpegPhoto</LdapProfileImageAttribute>
    <LdapProfileImageFormat>Default</LdapProfileImageFormat>
    <EnableAllFolders>true</EnableAllFolders>
    <EnabledFolders />
    <PasswordResetUrl>${passwordResetUrl}</PasswordResetUrl>
  </PluginConfiguration>
''
