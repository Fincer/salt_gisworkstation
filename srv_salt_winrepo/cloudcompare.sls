cloudcompare:
  '2.10.alpha':
    installer: salt://win/repo-ng/installers/CloudCompare_v2.10.alpha_setup_x64.exe
    full_name: 'CloudCompare 2.10 Alpha'
    reboot: False
    install_flags: '/silent /norestart'
    uninstaller: '%ProgramFiles%/CloudCompare/unins001.exe'
    uninstall_flags: '/silent /norestart'
