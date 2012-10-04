package Coro::LocalScalar;
use strict;
no strict 'refs';
use Guard;
use Carp;
use Scalar::Util qw/weaken blessed/;
our $VERSION = '0.2';

=head1 NAME

Coro::LocalScalar - local() for Coro

=head1 ABOUT

Perl local() function unuseful for Coro threads. This module uses tie magick to make scalar local for each Coro thread. Unlike L<Coro::Specific> this module destroys all data attached to coroutine when coroutine gets destroyed. It's useful when you need to call destructors of coroutine local objects when coroutine destroyed. And you can easily localize value of hash with this module

=head1 SYNOPSIS

	use Coro;
	use Coro::LocalScalar;
	use Coro::EV;
	
	my $scalar;
	
	Coro::LocalScalar->new->localize($scalar);
	# or just
	Coro::LocalScalar->new($scalar);
	
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
	EV::loop;

	

prints

	1 - thread 1
	2 - thread 2
	3 - thread 1
	4 - thread 2
	5 - thread 1
	6 - thread 2



	my $obj = Coro::LocalScalar->new;
	
		# no tie magick used
	$obj->value("data");
	$obj->value = "data"; 
	my $value = $obj->value;
	
	#or
	
	my $local_lvalue_closure = $obj->closure; # lvalue coderef
	
	$local_lvalue_closure->() = "local data"; # no tie magick used
	

	
	my $testobj = Someclass->new;
	
	# attach setter/getter and tied hash element to your object
	$obj->attach($testobj, 'element_local_in_coros');
	
	$testobj->element_local_in_coros("data");
	$testobj->element_local_in_coros = "data";
	
	$testobj->{element_local_in_coros}; # tie magick used


=cut





sub TIESCALAR {$_[1]};

sub closure { 
	my $self = shift;
	
	return sub :lvalue {
		$self->get;
	}
}

sub localize { # tie scalar to container
	my $self = $_[0];
	
	unless( blessed $self){
		$self = bless {};
	}
	
	$self->{old_scalars_refs} = [] unless($self->{old_scalars_refs});
	
	if(exists $_[1]){
		tie($_[1], __PACKAGE__, $self ) unless tied($_[1]);
		
		push @{ $self->{old_scalars_refs} } , \$_[1];
		weaken @{ $self->{old_scalars_refs} }[ int(@{ $self->{old_scalars_refs} })-1 ];
	}
	
	$self;
}
*new = *localize;


sub attach { # attach setter/getter and tied hash element to class
	# $container->attach($comeobj, 'db_conn'); $comeobj->{db_conn} and $comeobj->db_conn now local in Coros
	*{ref($_[1]).'::'.$_[2]} = $_[0]->closure;
	
	$_[1]->{$_[2]} = undef unless exists $_[1]->{$_[2]};
	$_[0]->localize($_[1]->{$_[2]});
	
	$_[0];
}


sub _proto : lvalue {
	my $self = shift;
	
	unless($Coro::current->{_CLS_ondestroy_set}){
		$Coro::current->{_CLS_ondestroy_set} = 1;
		
		$Coro::current->on_destroy(sub {
				${$_} = undef for(@{ $self->{old_scalars_refs} }); # Delete scalar value to prevent unexpected behavior
				# perl stores values in scalar even if it tied. When Coro::LocalScalar destroys internal value, value stored in scalar still persists although you expected that it would be deleted( and DESTROY called if it`s object)
		});
	}
	
	if(@_){ $Coro::current->{_CLS_data}{$self} = $_[0] }
	
	$Coro::current->{_CLS_data}{$self};
}

*STORE = *_proto;

sub FETCH : lvalue { $Coro::current->{_CLS_data}{$_[0]} };


our $AUTOLOAD;
sub AUTOLOAD :lvalue { *{$AUTOLOAD} = *_proto; $_[0]->_proto }

sub DESTROY {}
sub UNTIE {};

1;