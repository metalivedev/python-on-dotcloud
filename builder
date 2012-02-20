#!/usr/bin/env bash

shopt -s extglob

nginx_install_dir="$HOME/nginx"
nginx_stage_dir="$HOME/stage"

msg() {
    echo -e "\033[1;32m-->\033[0m $0:" $*
}

die() {
    msg $*
    exit 1
}

move_to_approot() {
    [ -n "$SERVICE_APPROOT" ] && cd $SERVICE_APPROOT
}

install_uwsgi() {
    msg "install uwsgi from pip:"
    /home/dotcloud/env/bin/pip install uwsgi
}

install_nginx() {
    local nginx_url="http://nginx.org/download/nginx-1.0.12.tar.gz"

    msg "Nginx install directory: $nginx_install_dir"

    # install nginx
    if [ ! -d $nginx_install_dir ] ; then
        mkdir -p $nginx_install_dir

        wget -O - $nginx_url | tar -C $nginx_stage_dir --strip-components=1 -zxf -
        [ $? -eq 0 ] || die "can't fetch nginx"

        export CFLAGS="-O3 -pipe"
        $nginx_stage_dir/configure   \
            --prefix=$nginx_install_dir \
            --with-http_addition_module \
            --with-http_dav_module \
            --with-http_geoip_module \
            --with-http_gzip_static_module \
            --with-http_realip_module \
            --with-http_stub_status_module \
            --with-http_ssl_module \
            --with-http_sub_module \
            --with-http_xslt_module
        [ $? -eq 0 ] || die "Nginx install failed"

        rm $nginx_install_dir/conf/*.default
    else
        msg "Nginx already installed"
    fi

    msg "Moving the uswgi_parmams file into place"
    cp -n uswgi_params $nginx_install_dir/conf/
    
    # update nginx configuration file
    # XXX: PORT_WWW is missing in the environment at build time
    sed > $nginx_install_dir/conf/nginx.conf < nginx.conf.in    \
        -e "s/@PORT_WWW@/${PORT_WWW:-42800}/g"
}


install_application() {
    cat >> profile << EOF
export PATH="$nginx_install_dir/sbin:$PATH"
EOF
    mv profile ~/

    # Use ~/code and ~/current like the regular Ruby service for better compatibility
    msg "installing application to ~/current/"
    rsync -aH --delete --exclude "data" * ~/current/
}

move_to_approot
install_uwsgi
install_nginx # could be replaced by something else
install_application