FROM ubuntu:22.04

WORKDIR /root

RUN echo "alias l='ls -lahAF'" > /root/.bashrc && \
    ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime

RUN apt update -qq && apt update -y
RUN apt install -y build-essential python3 python3-pip sudo curl wget git vim aptitude xterm x11-apps gnuradio gir1.2-gtk-3.0 usbutils rtl-sdr gr-osmosdr #gqrx-sdr
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3    /usr/bin/pip
COPY rtl-sdr.rules /etc/udev/rules.d/rtl-sdr.rules
COPY Miniforge3-Linux-aarch64.sh .
#COPY 20.rtl-sdr.rules /etc/udev/rules.d/20.rtl-sdr.rules
RUN echo "blacklist dvb_usb_rtl28xxu" >> /etc/modprobe.d/rtl28xxu-blacklist.conf
COPY setup.sh .
RUN ./setup.sh kraken
