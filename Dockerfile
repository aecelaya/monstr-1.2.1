# Start from scratch
FROM ubuntu:latest

# Start as root for sufficient permissions
USER root

# Install dependencies
RUN echo "Installing dependencies..."
RUN apt-get update
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y apt-utils \
                                                        dpkg \
                                                        curl \
                                                        python3 \
                                                        python-is-python3 \
                                                        python3-pip \
                                                        bc \
                                                        libncurses5 \
                                                        libxext6 \
                                                        libxmu6 \
                                                        libxpm-dev \
                                                        libxt6 \
                                                        git-all \
                                                        unzip \
                                                        dc \
                                                        file \
                                                        libfontconfig1 \
                                                        libfreetype6 \
                                                        libgl1-mesa-dev \
                                                        libgl1-mesa-dri \
                                                        libglu1-mesa-dev \
                                                        libgomp1 \
                                                        libice6 \
                                                        libxcursor1 \
                                                        libxft2 \
                                                        libxinerama1 \
                                                        libxrandr2 \
                                                        libxrender1 \
                                                        libxt6 \
                                                        sudo \
                                                        wget \
                                                        ed \
                                                        gsl-bin \
                                                        libglib2.0-0 \
                                                        libglu1-mesa-dev \
                                                        libglw1-mesa \
                                                        libgomp1 \
                                                        libjpeg62 \
                                                        libnlopt-dev \
                                                        libxm4 \
                                                        netpbm \
                                                        r-base \
                                                        r-base-dev \
                                                        tcsh \
                                                        xfonts-base \
                                                        xvfb \
                                                        cmake \ 
                                                        openjdk-14-jdk \ 
                                                        nano
                                                        
RUN apt-get clean

# Install AFNI
RUN echo "Installing AFNI..."
ENV PATH="/opt/afni-latest:$PATH" \
    AFNI_PLUGINPATH="/opt/afni-latest"
RUN curl -sSL --retry 5 -o /tmp/multiarch.deb http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/multiarch-support_2.27-3ubuntu1_amd64.deb \
    && apt-get install /tmp/multiarch.deb
RUN curl -sSL --retry 5 -o /tmp/toinstall.deb http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb \
    && dpkg -i /tmp/toinstall.deb \
    && rm /tmp/toinstall.deb \
    && curl -sSL --retry 5 -o /tmp/toinstall.deb http://snapshot.debian.org/archive/debian-security/20160113T213056Z/pool/updates/main/libp/libpng/libpng12-0_1.2.49-1%2Bdeb7u2_amd64.deb \
    && dpkg -i /tmp/toinstall.deb \
    && rm /tmp/toinstall.deb \
    && apt-get install -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && gsl2_path="$(find / -name 'libgsl.so.19' || printf '')" \
    && if [ -n "$gsl2_path" ]; then \
         ln -sfv "$gsl2_path" "$(dirname $gsl2_path)/libgsl.so.0"; \
    fi \
    && ldconfig \
    && mkdir -p /opt/afni-latest \
    && curl -fsSL --retry 5 https://afni.nimh.nih.gov/pub/dist/tgz/linux_openmp_64.tgz \
    | tar -xz -C /opt/afni-latest --strip-components 1 \
    && PATH=$PATH:/opt/afni-latest rPkgsInstall -pkgs ALL
           
# Install dicom2nifti and other Python packages
RUN echo "Installing Python packages..."
RUN pip3 install dicom2nifti \
                 numpy \
                 pandas \ 
                 SimpleITK

# Install C3D
RUN echo "Installing Convert3D..."
ENV C3DPATH="/opt/convert3d-1.0.0" \
    PATH="/opt/convert3d-1.0.0/bin:$PATH"
RUN mkdir -p /opt/convert3d-1.0.0 \
    && curl -fsSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz/download | tar -xz -C /opt/convert3d-1.0.0 --strip-components 1

# Install latest (i.e., nightly) version of C3D
# ENV C3DPATH="/opt/convert3d-nightly" \
#     PATH="/opt/convert3d-nightly/bin:$PATH"
# RUN echo "Downloading Convert3D ..." \
#     && mkdir -p /opt/convert3d-nightly \
#     && curl -fsSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/Nightly/c3d-nightly-Linux-x86_64.tar.gz/download \
#     | tar -xz -C /opt/convert3d-nightly --strip-components 1

# Install ANTs
RUN echo "Installing ANTs..."
ENV ANTSPATH="/opt/ants-2.3.1" \
    PATH="/opt/ants-2.3.1:$PATH"
RUN mkdir -p /opt/ants-2.3.1 \
    && curl -fsSL --retry 5 https://dl.dropbox.com/s/1xfhydsf4t4qoxg/ants-Linux-centos6_x86_64-v2.3.1.tar.gz | tar -xz -C /opt/ants-2.3.1 --strip-components 1

# Install ANTsR
RUN echo "Installing ANTsR..."
RUN git clone https://github.com/stnava/ITKR.git \
    && git clone https://github.com/ANTsX/ANTsRCore.git \
    && git clone https://github.com/ANTsX/ANTsR.git
RUN R CMD INSTALL ITKR \
    && R CMD INSTALL ANTsRCore \
    && R CMD INSTALL ANTsR

# Install Matlab Compiler 2015b
RUN echo "Installing MATLAB Compiler Runtime..."
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu:/opt/matlabmcr-2015b/v90/runtime/glnxa64:/opt/matlabmcr-2015b/v90/bin/glnxa64:/opt/matlabmcr-2015b/v90/sys/os/glnxa64:/opt/matlabmcr-2015b/v90/extern/bin/glnxa64" \
    MATLABCMD="/opt/matlabmcr-2015b/v90/toolbox/matlab"
RUN export TMPDIR="$(mktemp -d)" \
    && curl -fsSL --retry 5 -o "$TMPDIR/mcr.zip" https://ssd.mathworks.com/supportfiles/downloads/R2015b/deployment_files/R2015b/installers/glnxa64/MCR_R2015b_glnxa64_installer.zip \
    && unzip -q "$TMPDIR/mcr.zip" -d "$TMPDIR/mcrtmp" \
    && "$TMPDIR/mcrtmp/install" -destinationFolder /opt/matlabmcr-2015b -mode silent -agreeToLicense yes \
    && rm -rf "$TMPDIR" \
    && unset TMPDIR

# Install FSL
RUN echo "Installing FSL..."
ENV FSLDIR="/opt/fsl-6.0.3" \
    PATH="/opt/fsl-6.0.3/bin:$PATH" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    FSLTCLSH="/opt/fsl-6.0.3/bin/fsltclsh" \
    FSLWISH="/opt/fsl-6.0.3/bin/fslwish" \
    FSLLOCKDIR="" \
    FSLMACHINELIST="" \
    FSLREMOTECALL="" \
    FSLGECUDAQ="cuda.q"
RUN mkdir -p /opt/fsl-6.0.3 \
    && curl -fsSL --retry 5 https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-6.0.3-centos6_64.tar.gz | tar -xz -C /opt/fsl-6.0.3 --strip-components 1 \
    && bash /opt/fsl-6.0.3/etc/fslconf/fslpython_install.sh -f /opt/fsl-6.0.3

# Install MONSTR
RUN echo "Installing MONSTR..."
ENV PATH="/opt/monstr-1.2.1:$PATH"
RUN mkdir -p /opt/monstr-1.2.1 \
    && curl -o /opt/monstr-1.2.1/monstr-1.2.1.zip https://www.nitrc.org/frs/download.php/11560/MONSTR1.2.1.zip \
    && unzip /opt/monstr-1.2.1/monstr-1.2.1.zip -d /opt/monstr-1.2.1/ \
    && rm /opt/monstr-1.2.1/monstr-1.2.1.zip \
    && curl -o /opt/monstr-1.2.1/MONSTR.sh https://raw.githubusercontent.com/aecelaya/monstr-1.2.1/master/MONSTR.sh \
    && curl -o /opt/monstr-1.2.1/run_create_brainmask.sh https://raw.githubusercontent.com/aecelaya/monstr-1.2.1/master/run_create_brainmask.sh \
    && curl -o /opt/monstr-1.2.1/run_image_dilate.sh https://raw.githubusercontent.com/aecelaya/monstr-1.2.1/master/run_image_dilate.sh

# Create directories for scripts, data, model, and output
RUN echo "Creating working directory and copying data..."
WORKDIR /app

# Get atlases into /app folder
RUN mkdir /app/atlas \
    && curl -o /app/atlas/atlas.zip https://www.nitrc.org/frs/download.php/10160/Atlases1.1.zip \
    && unzip /app/atlas/atlas.zip -d /app/atlas/ \
    && rm /app/atlas/atlas.zip
    
RUN mkdir /data \
          && /model \
          && /out 
    
# RUN curl -o /app/GetKi67.py https://raw.githubusercontent.com/aecelaya/ki67-docker/master/GetKi67.py
# ENTRYPOINT ["python", "GetKi67.py"]
