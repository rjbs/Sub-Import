use strict;
use warnings;

package Sub::Import;
# ABSTRACT: import routines from most anything using Sub::Exporter

use B qw(svref_2object);
use Carp ();
use Exporter ();
use Params::Util qw(_CLASS);

my %methods;

sub import {
  my ($self, $target, @args) = @_;

  my $import = $self->get_import($target);

  $target->$import(@args);
}

sub unimport {
  my ($self, $target, @args) = @_;

  my $unimport = $self->get_unimport($target);

  $target->$unimport(@args);
}

sub get_unimport {
  my ($self, $target) = @_;

  $self->get_methods($target)->{unimport};
}

sub get_import {
  my ($self, $target) = @_;

  $self->get_methods($target)->{import};
}

sub get_methods {
  my ($self, $target) = @_;

  $methods{$target} ||= $self->create_methods($target);
}

sub require_class {
  my ($self, $class) = @_;

  Carp::croak("invalid package name: $class") unless _CLASS($class);

  local $@;
  eval "require $class; 1" or die;

  return;
}

sub _is_sexy {
  my ($self, $class) = @_;

  local $@;
  eval {
    my $obj = svref_2object( Foo->can('import') );
    my $importer_pkg = $obj->START->stashpv;
    return _CLASSISA($importer_pkg, 'Sub::Exporter');
  };

  return;
}

my $EXPORTER_IMPORT;
BEGIN { $EXPORTER_IMPORT = Exporter->can('import'); }
sub _is_exporterrific {
  my ($self, $class) = @_;
  
  my $class_import = do {
    local $@;
    eval { $class->can('import') };
  };

  return unless $class_import;
  return $class_import == $EXPORTER_IMPORT;
}

sub create_methods {
  my ($self, $target) = @_;

  $self->require_class($target);

  if ($self->_is_sexy($target)) {
    return {
      import   => "import",
      unimport => "unimport",
    };
  } elsif ($self->_is_exporterrific($target)) {
    return $self->create_methods_exporter($target);
  } else {
    return $self->create_methods_fallback($target);
  }
}

sub create_methods_exporter {
  my ($self, $target) = @_;

  no strict 'refs';

  my @ok      = @{ $target . "::EXPORT_OK" };
  my @default = @{ $target . "::EXPORT" };

  my @all = do {
    my %seen;
    grep { !$seen{$_}++ } @ok, @default;
  };

  my $import = Sub::Exporter::build_exporter(
    {
      exports => \@all,
      groups  => { default => \@default, }
    }
  );

  return {
    import   => $import,
    unimport => sub { },
  };
}

sub create_methods_fallback {
  my ($self, @target) = @_;

  return {
    import => do {

      package Sub::Importer::Scratch;

      sub {
        my ($class, @import) = @_;

        my $actual_import = caller();

        # parse @import as S'Ex directives
        # wind up with the low level import list
        # generators are obviously not really possible,

        my @actual_import = @import;

        $class->import(@actual_import);

        no strict 'refs';

        my %imported = %{ __PACKAGE__ . "::" };
        %{ __PACKAGE__ . "::" } = ();

        wrap_and_shit(\%imported, @import, into => $actual_import);
      }
    },

    unimport => sub { },
  };
}

