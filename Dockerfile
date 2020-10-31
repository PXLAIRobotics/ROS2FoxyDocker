FROM osrf/ros:foxy-desktop

# After FROM, enter the parent image from wich you want to build.
# We choose foxy-desktop.

# Currently, we are operating as root.

# Environment variable -> set language to C (computer) UTF-8 (8 bit unicode transformation format).
ENV LANG C.UTF-8

# Debconf is used to perform system-wide configutarions.
# Noninteractive -> use default settings -> put in debconf db.
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Set the nvidia container runtime.
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
    ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics

# Environment variable -> see output in real time.
ENV PYTHONUNBUFFERED 1

# Install some handy tools.
RUN set -x \
        && apt-get update \
        && apt-get upgrade -y \
        && apt-get install -y apt-utils \
        && apt-get install -y mesa-utils \
        && apt-get install -y iputils-ping \
        && apt-get install -y apt-transport-https ca-certificates \
        && apt-get install -y openssh-server python3-pip exuberant-ctags \
        && apt-get install -y git vim tmux nano htop sudo curl wget gnupg2 \
        && apt-get install -y bash-completion \
        && pip3 install powerline-shell \
        && rm -rf /var/lib/apt/lists/* \
        && useradd -ms /bin/bash user \
        && echo "user:user" | chpasswd && adduser user sudo \
        && echo "user ALL=(ALL) NOPASSWD: ALL " >> /etc/sudoers

# The OSRF container didn't link python3 to python, causing ROS scripts to fail.
RUN ln -s /usr/bin/python3 /usr/bin/python

# Set USER to user + define working directory.
USER user
WORKDIR /home/user

# tmux
RUN git clone https://github.com/jimeh/tmux-themepack.git ~/.tmux-themepack  \
        && git clone https://github.com/tmux-plugins/tmux-resurrect ~/.tmux-resurrect
COPY --chown=user:user ./.tmux.conf /home/user/.tmux.conf
COPY --chown=user:user ./.powerline.sh /home/user/.powerline.sh

# vim
RUN mkdir -p /home/user/.vim/bundle \
        && git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

COPY --chown=user:user ./.vimrc /home/user/.vimrc

RUN set -x \
        && vim -E -u NONE -S /home/user/.vimrc -C "+PluginInstall" -C "+qall";  exit 0

# Set some decent colors if the container needs to be accessed via /bin/bash.
RUN echo LS_COLORS=$LS_COLORS:\'di=1\;33:ln=36\' >> ~/.bashrc \
        && echo export LS_COLORS >> ~/.bashrc \
        && echo 'source ~/.powerline.sh' >> ~/.bashrc \
        && echo 'alias tmux="tmux -2"' >> ~/.bashrc \
        && echo 'PATH=~/bin:$PATH' >> ~/.bashrc \
        && touch ~/.sudo_as_admin_successful # To surpress the sudo message at run.

RUN rosdep update \
        && echo "source /opt/ros/foxy/setup.bash" >> /home/user/.bashrc

RUN mkdir -p Projects/dev_ws/src

RUN echo "source /usr/share/colcon_cd/function/colcon_cd.sh" >> /home/user/.bashrc \
        && echo "export _colcon_cd_root=/home/user/Projects/dev_ws" >> /home/user/.bashrc \
		&& /bin/bash -c '. /opt/ros/foxy/setup.bash; cd /home/user/Projects/dev_ws; colcon build'

RUN echo "source /home/user/Projects/dev_ws/install/setup.bash --extend" >> /home/user/.bashrc

RUN echo 'PATH=~/.local/bin:$PATH' >> ~/.bashrc

STOPSIGNAL SIGTERM

CMD sudo service ssh start && /bin/bash
