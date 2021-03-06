set -e
set -x

export INSTALL_PREFIX=~/miniconda
export PATH=$INSTALL_PREFIX/bin:$PATH


osx_setup() {
    brew update || brew update

    brew outdated openssl || brew upgrade openssl
    brew install zsh

    rvm get head
}


install_python() {
    # strategy is to use Miniconda to install python, but then remove all vestiges of conda
   curl -sSL $MINICONDA_URL -o ~/miniconda.sh
   chmod +x ~/miniconda.sh
   mkdir -p $INSTALL_PREFIX
   ~/miniconda.sh -bfp $INSTALL_PREFIX
   hash -r
   $INSTALL_PREFIX/bin/conda install -y -q python=$PYTHON_VERSION
   local site_packages=$($INSTALL_PREFIX/bin/python -c "from distutils.sysconfig import get_python_lib as g; print(g())")
   rm -rf $INSTALL_PREFIX/bin/activate \
       $INSTALL_PREFIX/bin/conda \
       $INSTALL_PREFIX/bin/conda-env \
       $INSTALL_PREFIX/bin/deactivate \
       $INSTALL_PREFIX/conda-meta/conda-*.json \
       $INSTALL_PREFIX/conda-meta/requests-*.json \
       $INSTALL_PREFIX/conda-meta/pyopenssl-*.json \
       $INSTALL_PREFIX/conda-meta/cryptography-*.json \
       $INSTALL_PREFIX/conda-meta/idna-*.json \
       $INSTALL_PREFIX/conda-meta/ruamel-*.json \
       $INSTALL_PREFIX/conda-meta/pycrypto-*.json \
       $INSTALL_PREFIX/conda-meta/pycosat-*.json \
       $site_packages/conda* \
       $site_packages/requests* \
       $site_packages/pyopenssl* \
       $site_packages/cryptography* \
       $site_packages/idna* \
       $site_packages/ruamel* \
       $site_packages/pycrypto* \
       $site_packages/pycosat*
   hash -r
   $INSTALL_PREFIX/bin/python --version
   $INSTALL_PREFIX/bin/pip --version

}

miniconda_install() {
    curl -L https://repo.continuum.io/miniconda/Miniconda3-4.0.5-Linux-x86_64.sh -o ~/miniconda.sh
    bash ~/miniconda.sh -bfp $INSTALL_PREFIX
    hash -r
    $INSTALL_PREFIX/bin/conda install -y -q pip conda 'python>=3.6'
    $INSTALL_PREFIX/bin/conda info
    $INSTALL_PREFIX/bin/conda config --set auto_update_conda false
}


conda_build_install() {
    # install conda
    $INSTALL_PREFIX/bin/pip install -r utils/requirements-test.txt
    $INSTALL_PREFIX/bin/python utils/setup-testing.py install
    $INSTALL_PREFIX/bin/conda info

    # install conda-build test dependencies
    $INSTALL_PREFIX/bin/conda install -y -q pytest pytest-cov pytest-timeout mock
    $INSTALL_PREFIX/bin/conda install -y -q -c conda-forge perl pytest-xdist
    $INSTALL_PREFIX/bin/conda install -y -q anaconda-client numpy

    $INSTALL_PREFIX/bin/pip install pytest-catchlog pytest-mock

    $INSTALL_PREFIX/bin/conda config --set add_pip_as_python_dependency true

    # install conda-build runtime dependencies
    $INSTALL_PREFIX/bin/conda install -y -q filelock jinja2 patchelf conda-verify setuptools contextlib2 pkginfo

    # install conda-build
    git clone -b $CONDA_BUILD --single-branch --depth 1000 https://github.com/conda/conda-build.git
    rm -rf $($INSTALL_PREFIX/bin/python -c "import site; print(site.getsitepackages()[0])")/conda_build
    pushd conda-build
    $INSTALL_PREFIX/bin/pip install .
    hash -r
    conda info
    popd

    git clone https://github.com/conda/conda_build_test_recipe.git
}


# Set global variables for this script
case "$(uname -s)" in
    'Darwin')
        MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-4.2.12-MacOSX-x86_64.sh"
        osx_setup
        ;;
    'Linux')
        MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-4.2.12-Linux-x86_64.sh"
        ;;
    *)  ;;
esac


if [[ $FLAKE8 == true ]]; then
    pip install flake8
elif [[ $TRAVIS_SUDO == true ]]; then
    sudo -E -u root bash -c "source utils/functions.sh && install_conda_dev /usr/local"
    export INSTALL_PREFIX="/usr/local"
    export PATH=$INSTALL_PREFIX/bin:$PATH
    sudo -E -u root chown -R root:root ./conda
    ls -al ./conda
elif [[ -n $CONDA_BUILD ]]; then
    install_python
    conda_build_install
else
    install_python
    $INSTALL_PREFIX/bin/pip install -r utils/requirements-test.txt
fi
