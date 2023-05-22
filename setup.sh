#!/bin/bash

set -x
# Comment this back in for debugging
set -e

projdir=${HOME}/code
mkdir -p $projdir

## Debian based
#sudo apt update && sudo apt upgrade -y && sudo apt install -y build-essential aptitude htop curl git vim tmux zsh
#sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
#
## RbPi
## set ZSH_THEME="jonathan" near the top of the .zshrc file
#echo 'ZSH_THEME="jonathan"' >> ~/.zshrc
#sudo apt install -y xterm rtl-sdr gnuradio gr-osmosdr gr-soapy gr-limesdr limesuite
#mkdir -p $projdir
#cd $projdir
#git clone https://github.com/konimaru/cariboulite.git cariboulite_konimaru
#
### Alphafold docker container
### apt update && apt install -y rsync aria2


### Just for setting up rpi for sdr
if [ $1 = "initial" ]; then
  for folder in "Pictures Videos Music Bookshelf"; do [ -d $folder ] && rm -rf $folder; done
  sudo apt update
  DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates build-essential \
    aptitude htop curl git vim tmux zsh #xterm rtl-sdr gnuradio gr-osmosdr gr-soapy gr-limesdr limesuite
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  echo 'ZSH_THEME="jonathan"' >> ~/.zshrc # simple, looks nice, light weight
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

if [ $1 = "docker" ]; then
  curl -sSL https://get.docker.com | sh

  sudo apt install -y uidmap
  dockerd-rootless-setuptool.sh install

  #STARTHERE getting it working on raspian in docker, copy in docker file, rules, basic.grc
  #docker run --rm -it --privileged -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v ./:/root/docker_gnuradio -w /root/docker_gnuradio ubu2204gnuradio:latest bash
  #sudo apt install -y rtl-sdr
  #udev rules
  #echo "blacklist dvb_usb_rtl28xxu" >> /etc/modprobe.d/blacklist_rtl28xxu.conf
  #docker build -t ubu2204gnuradio:latest .
fi

# Install cariboulite
if [ $1 = "caribou" ]; then
  cd $projdir
  git clone https://github.com/konimaru/cariboulite.git cariboulite_konimaru
fi

if [ $1 = "python" ]; then
  sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
    libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

  cd $projdir
  wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz
  tar -xf Python-3.10.*.tgz
  cd Python-3.10.*/
  ./configure --prefix=/usr/local --enable-optimizations --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
  make -j$(nproc)
  sudo make altinstall
fi

# Install GNURadio (working on Raspberry Pi 400 20230517 and took maybe half an hour)
if [ $1 = "gnuradio" ]; then
  #TODO move this swap section to it's own area
  #sudo fallocate -l 2G /swapfile
  #sudo chmod 600 /swapfile
  #sudo mkswap /swapfile
  #sudo swapon /swapfile

  sudo apt install -y cmake g++ libboost-all-dev libgmp-dev swig python3-numpy \
    python3-mako python3-sphinx python3-lxml doxygen libfftw3-dev \
    libsdl1.2-dev libgsl-dev libqwt-qt5-dev libqt5opengl5-dev python3-pyqt5 \
    liblog4cpp5-dev libzmq3-dev python3-yaml python3-click python3-click-plugins \
    python3-zmq python3-scipy python3-gi python3-gi-cairo gir1.2-gtk-3.0 \
    libcodec2-dev libgsm1-dev libusb-1.0-0 libusb-1.0-0-dev libudev-dev \
    libiio-dev libad9361-dev libspdlog-dev python3-mako python3-packaging python3-jsonschema

  cd $projdir
  [ -d volk ] && rm -rf volk
  git clone --recursive https://github.com/gnuradio/volk.git
  cd volk
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DPYTHON_EXECUTABLE=/usr/bin/python3 ../
  make -j$(nproc)
  make test
  sudo make install
  sudo ldconfig

  cd $projdir
  [ -d gnuradio ] && rm -rf gnuradio
  git clone https://github.com/gnuradio/gnuradio.git
  cd gnuradio
  git checkout maint-3.10
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DPYTHON_EXECUTABLE=/usr/bin/python3 ../
  make -j$(nproc)
  make test
  sudo make install

  echo "export PYTHONPATH=/usr/local/lib/python3.9/dist-packages:/usr/local/lib/python3.9/site-packages:/home/chris/GRadio/lib/python3.6/site-packages/" >> ~/.zshrc
  echo "export LD_LIBRARY_PATH=/usr/local/lib" >> ~/.zshrc

  sudo ldconfig
  volk_profile
  #sudo reboot
fi

# TODO how do I make this headless?
# Install gr-krakensdr in an Ubuntu 22.04 docker container
if [ $1 = "kraken" ]; then
  sudo apt-get install -y gnuradio-dev cmake libspdlog-dev clang clang-format

  cd $projdir
  [ -d gr-krakensdr ] && rm -rf gr-krakensdr
  git clone https://github.com/krakenrf/gr-krakensdr.git
  cd gr-krakensdr
  mkdir build
  cd build
  cmake ..
  make -j$(nproc)
  sudo make install

  # Heimdall
  # 1. dependencies
  sudo apt update
  sudo apt install -y build-essential git cmake libusb-1.0-0-dev lsof libzmq3-dev

  # 2. custom kernel driver
  cd $projdir
  [ -d librtlsdr ] && rm -rf librtlsdr
  git clone https://github.com/krakenrf/librtlsdr.git
  cd librtlsdr
  sudo cp rtl-sdr.rules /etc/udev/rules.d/rtl-sdr.rules
  mkdir build
  cd build
  cmake ../ -DINSTALL_UDEV_RULES=ON
  make -j$(nproc)
  sudo ln -s ~/librtlsdr/build/src/rtl_test /usr/local/bin/kraken_test

  #echo 'blacklist dvb_usb_rtl28xxu' | sudo tee --append /etc/modprobe.d/blacklist-dvb_usb_rtl28xxu.conf

  #sudo reboot

  # 3. Ne10
  cd $projdir
  [ -d Ne10 ] && rm -rf Ne10
  git clone https://github.com/krakenrf/Ne10.git
  cd Ne10
  mkdir build
  cd build
  cmake -DNE10_LINUX_TARGET_ARCH=aarch64 -DGNULINUX_PLATFORM=ON -DCMAKE_C_FLAGS="-mcpu=native -Ofast -funsafe-math-optimizations" ..
  make -j$(nproc)

  # 4. Miniforge (only works on 64 bit)
  cd
  #wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
  #chmod ug+x Miniforge3-Linux-aarch64.sh
  # Edit to remove all read commands
  SHELL=/bin/bash ./Miniforge3-Linux-aarch64.sh
  # Answer yes to all questions
  # sudo reboot
  # or
  source ~/.bashrc
  conda config --set auto_activate_base false
  # sudo reboot
  # or
  source ~/.bashrc

  # 5. Miniconda setup
  conda create --yes -n kraken python=3.9.7
  conda activate kraken

  conda install --yes scipy==1.9.3
  conda install --yes numba
  conda install --yes configparser
  conda install --yes pyzmq
  conda install --yes scikit-rf

  # 6. Heimdall Firmware
  cd $projdir
  mkdir krakensdr
  cd krakensdr

  [ -d heimdall_daq_fw] && rm -rf heimdall_daq_fw
  git clone https://github.com/krakenrf/heimdall_daq_fw.git
  cd $projdir/krakensdr/heimdall_daq_fw/Firmware/_daq_core/
  cp $projdir/librtlsdr/build/src/librtlsdr.a .
  cp $projdir/librtlsdr/include/rtl-sdr.h .
  cp $projdir/librtlsdr/include/rtl-sdr_export.h .
  cp $projdir/Ne10/build/modules/libNE10.a .

  cp $projdir/gr-krakensdr/heimdall_only_start.sh $projdir/krakensdr/
  cp $projdir/gr-krakensdr/heimdall_only_stop.sh $projdir/krakensdr/

  # 7. Kraken DoA DSP (direction of arrival) Some of the install instructions are duplicate of what I've done earlier.
  cd $projdir/krakensdr
  git clone https://github.com/krakenrf/krakensdr_doa.git
  cp krakensdr_doa/util/kraken_doa_start.sh .
  cp krakensdr_doa/util/kraken_doa_stop.sh .
fi


#install gnuradio only, the following new packges will be installed
#fonts-liberation fonts-lyx gdal-data gnuradio gnuradio-dev graphviz icu-devtools libaec0 libann0
#  libarmadillo10 libarpack2 libboost-atomic1.74-dev libboost-atomic1.74.0 libboost-chrono1.74-dev
#  libboost-chrono1.74.0 libboost-date-time1.74-dev libboost-date-time1.74.0
#  libboost-filesystem1.74-dev libboost-program-options1.74-dev libboost-regex1.74-dev
#  libboost-serialization1.74-dev libboost-serialization1.74.0 libboost-system1.74-dev
#  libboost-system1.74.0 libboost-test1.74-dev libboost-test1.74.0 libboost-thread1.74-dev
#  libboost1.74-dev libcdt5 libcfitsio9 libcgraph6 libcharls2 libcppunit-1.15-0 libcppunit-dev
#  libdap27 libdapclient6v5 libepsilon1 libfftw3-bin libfftw3-dev libfftw3-long3 libfreexl1
#  libfyba0 libgdal28 libgeos-3.9.0 libgeos-c1v5 libgeotiff5 libgmp-dev libgmpxx4ldbl
#  libgnuradio-analog3.8.2 libgnuradio-audio3.8.2 libgnuradio-blocks3.8.2 libgnuradio-channels3.8.2
#  libgnuradio-digital3.8.2 libgnuradio-dtv3.8.2 libgnuradio-fec3.8.2 libgnuradio-fft3.8.2
#  libgnuradio-filter3.8.2 libgnuradio-pmt3.8.2 libgnuradio-qtgui3.8.2 libgnuradio-runtime3.8.2
#  libgnuradio-trellis3.8.2 libgnuradio-uhd3.8.2 libgnuradio-video-sdl3.8.2
#  libgnuradio-vocoder3.8.2 libgnuradio-wavelet3.8.2 libgnuradio-zeromq3.8.2 libgsl25 libgslcblas0
#  libgsm1-dev libgts-0.7-5 libgts-bin libgvc6 libgvpr2 libhdf4-0-alt libhdf5-103-1 libhdf5-hl-100
#  libheif1 libicu-dev libjs-jquery-ui libkmlbase1 libkmldom1 libkmlengine1 liblab-gamut1
#  liblbfgsb0 liblog4cpp5-dev liblog4cpp5v5 libmariadb3 libminizip1 libnetcdf18 libodbc1 libogdi4.1
#  libpathplan4 libportaudio2 libpq5 libproj19 libqhull8.0 libqt5opengl5 libqwt-qt5-6 librttopo1
#  libspatialite7 libsuperlu5 libsz2 libthrift-0.13.0 libthrift-dev libuhd3.15.0 liburiparser1
#  libvolk2-bin libvolk2-dev libvolk2.4 libxerces-c3.2 mariadb-common mysql-common odbcinst
#  odbcinst1debian2 proj-bin proj-data pyqt5-dev-tools python-matplotlib-data python3-click-plugins
#  python3-cycler python3-dateutil python3-decorator python3-gdal python3-kiwisolver python3-mako
#  python3-matplotlib python3-networkx python3-pydot python3-pygraphviz python3-pyparsing
#  python3-pyqt5.qtopengl python3-pyqt5.qwt python3-pyqtgraph python3-scipy python3-sip
#  python3-thrift python3-yaml python3-zmq qtbase5-dev-tools qtchooser thrift-compiler
#  ttf-bitstream-vera uhd-host
#
#intall gr-osmosdr only, The following NEW packages will be installed:
  #bladerf gr-fcdproplus gr-fosphor gr-iqbal gr-osmosdr libairspy0 libairspyhf1 libbladerf2
  #libfreesrp0 libglfw3 libgnuradio-fcdproplus3.8.0 libgnuradio-fosphor3.8.0
  #libgnuradio-iqbalance3.8.0 libgnuradio-osmosdr0.2.0 libhackrf0 libhamlib4 libhidapi-libusb0
  #liblimesuite20.10-1 libmirisdr0 libopengl0 libosmosdr0 librtaudio6 libsoapysdr0.7 libtecla1
  #limesuite-udev soapyosmo-common0.7 soapysdr0.7-module-airspy soapysdr0.7-module-all
  #soapysdr0.7-module-audio soapysdr0.7-module-bladerf soapysdr0.7-module-hackrf
  #soapysdr0.7-module-lms7 soapysdr0.7-module-mirisdr soapysdr0.7-module-osmosdr
  #soapysdr0.7-module-redpitaya soapysdr0.7-module-remote soapysdr0.7-module-rfspace
  #soapysdr0.7-module-rtlsdr soapysdr0.7-module-uhd
