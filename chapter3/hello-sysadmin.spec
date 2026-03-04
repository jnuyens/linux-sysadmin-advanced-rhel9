Name:           hello-sysadmin
Version:        1.0
Release:        1%{?dist}
Summary:        Hello script from Advanced Sysadmin course
License:        GPL-3.0
Source0:        hello-sysadmin.sh

%description
A simple hello-world script created during the Advanced Linux
Sysadmin course to practice RPM package building.

%prep
# Nothing to prepare - single script

%install
mkdir -p %{buildroot}/usr/local/bin
install -m 755 %{SOURCE0} %{buildroot}/usr/local/bin/hello-sysadmin.sh

%files
/usr/local/bin/hello-sysadmin.sh

%changelog
* Mon Jan 01 2026 Student <student@example.com> - 1.0-1
- Initial package for Advanced Sysadmin course
