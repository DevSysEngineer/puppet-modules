# @summary Creates or updates an Authentik admin user in a Docker Compose stack.
#
# This defined type talks directly to the running Authentik `server` Compose
# service with `ak shell`. It creates the user when missing, activates existing
# users, updates the requested email and password, and ensures membership of a
# superuser group. The password is accepted as `Sensitive[String]` and the
# generated Puppet `exec` command and guard are also marked sensitive so the
# secret is not written to normal Puppet output.
#
# Declare `docker::authentik` or an equivalent `docker::compose` stack before
# using this defined type. The `compose_name` parameter must match that Compose
# resource title. The stack must already be running; this resource does not start
# or restart Authentik.
#
# @example Create or repair an Authentik admin account
#   docker::authentik_admin { 'kevin.admin':
#     compose_name => 'authentik',
#     email        => 'info@example.org',
#     password     => Sensitive('replace-with-admin-password'),
#     require      => Class['docker::authentik'],
#   }
#
# @param compose_name
#   Title of the managed `docker::compose` resource for the Authentik stack.
#
# @param email
#   Email address to set on the Authentik user.
#
# @param password
#   Password assigned to the Authentik user. Supply it from Hiera or a profile as
#   a `Sensitive[String]` value.
#
# @param group_name
#   Authentik group that should grant superuser access to the managed user.
#
# @param timeout
#   Maximum time in seconds for each Docker Compose operation.
#
# @param username
#   Authentik username to manage. Defaults to the resource title.
#
# @api public
define docker::authentik_admin (
  Pattern[/\A[A-Za-z0-9_.-]+\z/]              $compose_name,
  Pattern[/\A[^\r\n]+\z/]                     $email,
  Sensitive[String]                           $password,
  Pattern[/\A[^\r\n]+\z/]                     $group_name   = 'authentik Admins',
  Integer[1]                                  $timeout      = 120,
  Optional[Pattern[/\A[A-Za-z0-9@._+-]+\z/]]  $username     = undef
) {
  # Resolve compose lookup resources published by docker::compose from its local path variables.
  $compose_defined = defined(Docker::Compose[$compose_name])
  $project_directory_resource = "docker_compose_${compose_name}_project_directory"
  $compose_file_resource = "docker_compose_${compose_name}_compose_file"
  $env_file_resource = "docker_compose_${compose_name}_env_file"
  $project_directory_defined = defined(File[$project_directory_resource])
  $compose_file_defined = defined(File[$compose_file_resource])
  $env_file_defined = defined(File[$env_file_resource])

  # Validate that the dependent compose stack is present and has published all required path resources.
  if (!$compose_defined) {
    $compose_fail_text = "docker::authentik_admin requires Docker::Compose[${compose_name}] in the catalog."
  } elsif (Docker::Compose[$compose_name]['ensure'] != present) {
    $compose_fail_text = "docker::authentik_admin requires Docker::Compose[${compose_name}] with ensure => present."
  } elsif (!$project_directory_defined) {
    $compose_fail_text = "docker::authentik_admin requires File[${project_directory_resource}] from Docker::Compose[${compose_name}]."
  } elsif (!$compose_file_defined) {
    $compose_fail_text = "docker::authentik_admin requires File[${compose_file_resource}] from Docker::Compose[${compose_name}]."
  } elsif (!$env_file_defined) {
    $compose_fail_text = "docker::authentik_admin requires File[${env_file_resource}] from Docker::Compose[${compose_name}]."
  } else {
    $compose_fail_text = undef
  }

  if ($compose_fail_text == undef) {
    # Read the exact paths from the resources managed by docker::compose.
    $project_directory = File[$project_directory_resource]['path']
    $compose_file = File[$compose_file_resource]['path']
    $env_file = File[$env_file_resource]['path']
    $service = 'server'

    # Resolve the optional username before validation and command construction.
    $username_correct = $username ? {
      undef   => $title,
      default => $username,
    }

    # Validate title-derived usernames and passwords before using them in the generated command.
    if ($username_correct =~ /\A[A-Za-z0-9@._+-]+\z/) {
      $password_unwrapped = $password.unwrap

      if ($password_unwrapped =~ /\A[^\r\n]+\z/) {
        # Escape all dynamic shell words at the Docker CLI boundary.
        $compose_file_shell = stdlib::shell_escape($compose_file)
        $compose_name_shell = stdlib::shell_escape($compose_name)
        $email_shell = stdlib::shell_escape($email)
        $env_file_shell = stdlib::shell_escape($env_file)
        $group_name_shell = stdlib::shell_escape($group_name)
        $password_shell = stdlib::shell_escape($password_unwrapped)
        $project_directory_shell = stdlib::shell_escape($project_directory)
        $service_shell = stdlib::shell_escape($service)
        $username_shell = stdlib::shell_escape($username_correct)

        # Keep the Compose invocation identical to the managed service identity.
        $compose_command = join([
            '/usr/bin/docker compose',
            "--project-name ${compose_name_shell}",
            "--project-directory ${project_directory_shell}",
            "--env-file ${env_file_shell}",
            "--file ${compose_file_shell}",
        ], ' ')

        # Pass managed Authentik values as environment variables to keep the Python block static.
        $authentik_env_args = join([
            "-e AK_ADMIN_USERNAME=${username_shell}",
            "-e AK_ADMIN_EMAIL=${email_shell}",
            "-e AK_ADMIN_PASSWORD=${password_shell}",
            "-e AK_ADMIN_GROUP=${group_name_shell}",
        ], ' ')

        # The guard confirms the user, password, active state, email, and superuser group membership.
        $check_python = join([
            'import os',
            'from authentik.core.models import Group, User',
            '',
            'username = os.environ["AK_ADMIN_USERNAME"]',
            'email = os.environ["AK_ADMIN_EMAIL"]',
            'password = os.environ["AK_ADMIN_PASSWORD"]',
            'group_name = os.environ["AK_ADMIN_GROUP"]',
            '',
            'try:',
            '    user = User.objects.get(username=username)',
            'except User.DoesNotExist:',
            '    raise SystemExit(1)',
            '',
            'if not user.is_active:',
            '    raise SystemExit(1)',
            'if user.email != email:',
            '    raise SystemExit(1)',
            'if not user.check_password(password):',
            '    raise SystemExit(1)',
            'if not user.groups.filter(name=group_name, is_superuser=True).exists():',
            '    raise SystemExit(1)',
        ], "\n")

        # The update path creates missing objects and only mutates existing fields that drifted.
        $update_python = join([
            'import os',
            'from authentik.core.models import Group, User',
            '',
            'username = os.environ["AK_ADMIN_USERNAME"]',
            'email = os.environ["AK_ADMIN_EMAIL"]',
            'password = os.environ["AK_ADMIN_PASSWORD"]',
            'group_name = os.environ["AK_ADMIN_GROUP"]',
            '',
            'user, created = User.objects.get_or_create(',
            '    username=username,',
            '    defaults={',
            '        "path": "users",',
            '        "name": username,',
            '        "email": email,',
            '    },',
            ')',
            '',
            'user.name = user.name or username',
            'user.path = user.path or "users"',
            'user.email = email',
            'user.is_active = True',
            'if created or not user.check_password(password):',
            '    user.set_password(password)',
            'user.save()',
            '',
            'group, group_created = Group.objects.get_or_create(',
            '    name=group_name,',
            '    defaults={"is_superuser": True},',
            ')',
            'if not group.is_superuser:',
            '    group.is_superuser = True',
            '    group.save()',
            'if not user.groups.filter(pk=group.pk).exists():',
            '    user.groups.add(group)',
            '',
            'print("authentik admin user %s is active and has superuser access through %s" % (username, group.name))',
        ], "\n")

        # Build heredoc commands for Puppet's shell provider so Python code is sent through stdin.
        $check_command = join([
            "${compose_command} exec -T ${authentik_env_args} ${service_shell} ak shell <<'PY'",
            $check_python,
            'PY',
        ], "\n")
        $update_command = join([
            "${compose_command} exec -T ${authentik_env_args} ${service_shell} ak shell <<'PY'",
            $update_python,
            'PY',
        ], "\n")

        # Run the Authentik mutation only when the guard detects drift.
        exec { "docker_authentik_admin_${compose_name}_${username_correct}":
          command   => Sensitive.new($update_command),
          cwd       => $project_directory,
          logoutput => false,
          provider  => shell,
          require   => Docker::Compose[$compose_name],
          timeout   => $timeout,
          unless    => Sensitive.new($check_command),
        }
      } else {
        fail('docker::authentik_admin password must not be empty or contain newlines.')
      }
    } else {
      fail('docker::authentik_admin usernames may only contain letters, numbers, at signs, dots, underscores, plus signs, and hyphens.')
    }
  } else {
    fail($compose_fail_text)
  }
}
