use strict;
no warnings;

use blib;
use utf8;
use Data::Dumper;

use Test::More;

BEGIN { use_ok('Coro::LocalScalar') };

use Coro;



# is( $, ".._.__..___utf8_файл.jpg", 'POST multipart filename escape' );

	
	my $scalar;
	
	Coro::LocalScalar->new->localize($scalar);
	
	async {
		$scalar = "thread 1";
		print "1 - $scalar\n";
		cede;
		print "3 - $scalar\n";
		cede;
		print "5 - $scalar\n";
		
	};
	
	async {
		$scalar = "thread 2";
		print "2 - $scalar\n";
		cede;
		print "4 - $scalar\n";
		cede;
		print "6 - $scalar\n";
	};
	
	cede for 1..100;
	
	done_testing();