cd ~/Downloads/
wget https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz
tar -xvf emacs-31.1.tar.xz
cd emacs-31.1
./autogen
./configure --sysconfdir=/etc --prefix=/usr --libexecdir=/usr/lib --localstatedir=/var --disable-build-details --with-cairo --with-harfbuzz --with-libsystemd --with-modules --with-native-compilation=aot --with-tree-sitter --with-pgtk
make bootstrap -j12
sudo make install
cd
