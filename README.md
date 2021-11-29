# Boot OS

Acquire and boot hundreds of old and new operating systems without the hassle.

**Status**: Early Work in Progress

## Use Cases

- Enthusiast running of Operating Systems.
- Operating System media archival.
- Booting multiple versions of a specific OS for comparisons.
- Bootstrapping production quality virtual machines.

## Vision

Boot OS aims to solve a number of areas with a few key design decisions.

### Wide Operating System Support

Boot OS aims to provide wide support for any architecture and version of any Operating System.
Utilizing metadata generation, Boot OS can scan release information from OS distribution sites and generate
the necessary metadata to allow Boot OS to boot and consume the OS.

#### Solved: Release Image Scanner

Boot OS contains metadata generators for Debian and Ubuntu that allow quick and simple bootstrapping of new and old releases.

### Out-of-Box Boot

Boot OS aims to provide an out-of-box boot experience where you can boot any defined Operating System without
configuring specifics. Utilizing QEMU and hardware profiles, Boot OS can assemble sane cross-platform hardware
together with live or installation media to allow you to focus on messing with the Operating System.

#### Work in Progress: Hands-free Installation

Boot OS will provide hands-free installation where possible. Utilizing methods such as the Debian preseed file, Boot OS
could provide sane defaults to allow installation to just work.

### Responsible Media Acquisition

A lot of operating systems are maintained by volunteers and use donations of resources to host old and new media.
Boot OS aims to use the distribution recommended ways of reducing load on mirrors when acquiring media directly at the source,
but also aims to provide distribution of media out-of-band from upstream mirrors.

#### Solved: Jigsaw Download

Boot OS contains an implementation of the jigsaw download system [recommended by Debian](https://www.debian.org/CD/jigdo-cd/) with agressive caching.
With this, you can responsibly download every Debian release for every architecture without destroying the bandwidth of mirrors.

#### Future: OS Bundles

Boot OS aims to add support for OS bundles which pack together large amounts of OS installation media for distribution outside
first party servers. This is useful for archival purposes as well. OS bundles have not been designed fully yet, but imagine
something akin to a well-compressed archive of multiple versions of an Operating System ISO.

#### Future: P2P Downloads

Boot OS will add support for P2P file sharing such as BitTorrent or IPFS.
