#!/usr/bin/env bash

set -eu

declare -r workdir="${PWD}"
declare -r temporary_directory='/tmp/openbsd-sysroot'

[ -d "${temporary_directory}" ] || mkdir "${temporary_directory}"

cd "${temporary_directory}"

declare -r targets=(
	'armv7'
	'amd64'
	'riscv64'
	'arm64'
	'powerpc64'
	'macppc'
	'sparc64'
	'octeon'
	'loongson'
	'hppa'
	'alpha'
	'i386'
)

for target in "${targets[@]}"; do
	case "${target}" in
		armv7)
			declare triplet='arm-unknown-openbsd';;
		arm64)
			declare triplet='aarch64-unknown-openbsd';;
		macppc)
			declare triplet='powerpc-unknown-openbsd';;
		powerpc64)
			declare triplet='powerpc64-unknown-openbsd';;
		sparc64)
			declare triplet='sparc64-unknown-openbsd';;
		octeon)
			declare triplet='mips64-unknown-openbsd';;
		loongson)
			declare triplet='mips64el-unknown-openbsd';;
		riscv64)
			declare triplet='riscv64-unknown-openbsd';;
		amd64)
			declare triplet='x86_64-unknown-openbsd';;
		i386)
			declare triplet='i386-unknown-openbsd';;
		hppa)
			declare triplet='hppa-unknown-openbsd';;
		alpha)
			declare triplet='alpha-unknown-openbsd';;
	esac
	
	declare output="${temporary_directory}/data.tgz"
	declare sysroot_directory="${workdir}/${triplet}"
	declare tarball_filename="${sysroot_directory}.tar.xz"
	
	[ -d "${sysroot_directory}" ] || mkdir "${sysroot_directory}"
	
	echo "- Generating sysroot for ${triplet}"
	
	if [ -f "${tarball_filename}" ]; then
		echo "+ Already exists. Skip"
		continue
	fi
	
	declare urls=(
		"https://mirrors.ucr.ac.cr/pub/OpenBSD/7.0/${target}/base70.tgz"
		"https://mirrors.ucr.ac.cr/pub/OpenBSD/7.0/${target}/comp70.tgz"
	)
	
	for url in "${urls[@]}"; do
		echo "- Fetching data from ${url}"
		
		curl \
			--url "${url}" \
			--retry '30' \
			--retry-all-errors \
			--retry-delay '0' \
			--retry-max-time '0' \
			--location \
			--silent \
			--output "${output}"
		
		echo "- Unpacking ${output}"
		
		tar --directory="${sysroot_directory}" --strip=2 --extract --file="${output}" './usr/lib' './usr/include'
	done
	
	cd "${sysroot_directory}/lib"
	
	while read source; do
		IFS='.' read -ra parts <<< "${source}"
		
		declare name="${parts[1]}"
		declare destination="${name#/}.so"
		
		ln --symbolic "${source}" "./${destination}"
	done <<< "$(find '.' -type 'f' -name 'lib*.so.*')"
	
	echo "- Creating tarball at ${tarball_filename}"
	
	tar --directory="$(dirname "${sysroot_directory}")" --create --file=- "$(basename "${sysroot_directory}")" | xz  --compress -9 > "${tarball_filename}"
	sha256sum "${tarball_filename}" | sed "s|$(dirname "${sysroot_directory}")/||" > "${tarball_filename}.sha256"
	
	rm --force --recursive "${sysroot_directory}"
	rm --force --recursive "${temporary_directory}/"*
done
