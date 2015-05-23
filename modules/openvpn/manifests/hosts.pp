class openvpn::hosts {
    #
    # Define /etc/hosts entries for every host except myself
    #
    Openvpn::Host <| title != $clientcert |>
}
