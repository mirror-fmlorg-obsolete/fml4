#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: Japanese.pm,v 1.2 2001/07/31 23:26:17 fukachan Exp $
#

#
# *** CAUTION: THIS FILE CODE IS JAPANESE EUC. ***
#

package Mail::Bounce::Language::Japanese;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

my $debug = $ENV{'debug'} ? 1 : 0;

@ISA = qw(Mail::Bounce);


=head1 NAME

Mail::Bounce::Language::Japanese - Japanese dependent error message parser

=head1 SYNOPSIS

See C<Mail::Bounce> for more details.

=head1 DESCRIPTION

See C<Mail::Bounce> for more details.

=head1 ERROR EXAMPLE

=head2 Lotus Notes

   �������顼��ݡ���
                                                                              
    ��̾:        [XXXXXXX:08268] Re: �ܤ����

    ������:      xxxxxxxx@chuo.tokyo.nuinui.net

    ����:        The peer SMTP host reports that it received bad SMTP command
                 syntax.

=head2 jp-r.ne.jp

   ������E-mail���ɥ쥹���԰��פǤ�
   To:****@jp-r.ne.jp
   Subject:** ���ä�subject������
   ** ���ä���ʸ��192ʸ����������

=head2 pakeo.ne.jp

  ���ʤ����������Ȥ������ɥ쥹��*********�פϡ���Ͽ����Ƥ��ޤ���
  �⤦���ٳ�ǧ���ơ��������ʤ����Ʋ�������

=cut


sub _japanese_address_match
{
    my ($self, $args) = @_;
    my ($addr, $mta_type);
    my $result = $args->{ result };
    my $rbuf   = $args->{ buf };
    my $buf    = $$rbuf;

    use Jcode;
    &Jcode::convert(\$buf, 'euc');

    print STDERR "rbuf={$buf}\n" if $debug;
    
    # lotus NOTES
    if ($buf =~ /������:\s*(\S+)/) {
	$addr     = $1;
	$mta_type = 'lotus notes';
    }
    # ������E-mail���ɥ쥹���԰��פǤ�
    # To:****@jp-r.ne.jp
    elsif ($buf =~ /To:\s*(\S+jp-r.ne.jp)/i) {
	$addr     = $1;
	$mta_type = 'jp-r.ne.jp';
    }
    # ���ʤ����������Ȥ������ɥ쥹��**@i.pakeo.ne.jp�פϡ���Ͽ����Ƥ��ޤ���
    elsif ($buf =~ 
	   /���ʤ����������Ȥ������ɥ쥹��(.*)�פϡ���Ͽ����Ƥ��ޤ���/) {
	$addr     = $1;
	$mta_type = 'pakeo.ne.jp';
    }

    if ($addr) {
	$result->{ $addr }->{ 'Final-Recipient' } = $addr;
	$result->{ $addr }->{ 'Status'}           = '5.x.y';
	$result->{ $addr }->{ 'hints' }           = $mta_type;
    }
}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself. 

=head1 HISTORY

Mail::Bounce::Language::Japanese appeared in fml5 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;