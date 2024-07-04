{
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
  poetry-core,
  hatchling,
  tox,
  distutils-extra,
  beautifulsoup4,
  soupsieve,
  markdown,
  pyyaml,
  wcmatch,
  lxml,
  html5lib,
  aspell-python,
}:
buildPythonPackage rec {
  pname = "pyspelling";
  version = "2.10";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-rNZxM8G3zs1BDj1EieYfLksfC2rPGubEjCQPuyFynDc=";
  };

  nativeBuildInputs = [
    setuptools
    setuptools-scm
    poetry-core
    hatchling
    tox
    distutils-extra
  ];

  propagatedBuildInputs = [
    beautifulsoup4
    soupsieve
    markdown
    pyyaml
    wcmatch
    lxml
    html5lib
    aspell-python
  ];
}
