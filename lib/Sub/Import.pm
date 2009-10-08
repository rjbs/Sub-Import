use strict;
use warnings;

package Sub::Import;
# ABSTRACT: import routines from most anything using Sub::Exporter

use B qw(svref_2object);
use Carp ();
use Exporter ();
use Params::Util qw(_CLASS _CLASSISA);
use Sub::Exporter ();

sub import {
  my ($self, $target, @args) = @_;

  my $import = $self->_get_import($target);

  @_ = ($target, @args);
  goto &$import;
}

sub unimport {
  my ($self, $target, @args) = @_;

  my $unimport = $self->_get_unimport($target);

  @_ = ($target, @args);
  goto &$unimport;
}

sub _get_unimport {
  my ($self, $target) = @_;

  $self->_get_methods($target)->{unimport};
}

sub _get_import {
  my ($self, $target) = @_;

  $self->_get_methods($target)->{import};
}

my %GENERATED_METHODS;
sub _get_methods {
  my ($self, $target) = @_;

  $GENERATED_METHODS{$target} ||= $self->_create_methods($target);
}

sub _require_class {
  my ($self, $class) = @_;

  Carp::croak("invalid package name: $class") unless _CLASS($class);

  local $@;
  eval "require $class; 1" or die;

  return;
}

sub _is_sexy {
  my ($self, $class) = @_;

  local $@;
  my $isa;
  my $ok = eval {
    my $obj = svref_2object( $class->can('import') );
    my $importer_pkg = $obj->START->stashpv;
    $isa = _CLASSISA($importer_pkg, 'Sub::Exporter');
    1;
  };

  return $isa;
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

sub _create_methods {
  my ($self, $target) = @_;

  $self->_require_class($target);

  if ($self->_is_sexy($target)) {
    return {
      import   => $target->can("import"),
      unimport => $target->can("unimport"),
    };
  } elsif ($self->_is_exporterrific($target)) {
    return $self->_create_methods_exporter($target);
  } else {
    return $self->_create_methods_fallback($target);
  }
}

sub _create_methods_exporter {
  my ($self, $target) = @_;

  no strict 'refs';

  my @ok      = @{ $target . "::EXPORT_OK"  };
  my @default = @{ $target . "::EXPORT"     };
  my %groups  = %{ $target . "::EXPORT_TAG" };

  my @all = do {
    my %seen;
    grep { ! $seen{$_}++ } @ok, @default;
  };

  my $import = Sub::Exporter::build_exporter({
    exports => \@all,
    groups  => {
      %groups,
      default => \@default,
    }
  });

  return {
    import   => $import,
    unimport => sub { die "unimport not handled for Exporter via Sub::Import" },
  };
}

sub _create_methods_fallback {
  my ($self, @target) = @_;

  Carp::confess(
    "Sub::Import only handles Sub::Exporter and Exporter-based import methods"
  );
}

1;
