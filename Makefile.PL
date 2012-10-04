use ExtUtils::MakeMaker;
my %options = (
  'TYPEMAPS' => [],
  'NAME' => 'Coro::LocalScalar',
  'VERSION' => '0.2',
  'BUILD_REQUIRES' => { 
	'Coro'  		=> 0,
	'Scalar::Util'	=> 0,
  },

);
WriteMakefile(%options);

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile { '' }
