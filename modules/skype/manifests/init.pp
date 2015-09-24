class skype {
    portage::package { 'net-im/skype':
        use => ['-pulseaudio', 'apulse'],
    }
}
