#Ses Proxy

SMTP Proxy for Amazon Simple Email Service with bounce and complaints support

##Installation

    gem install ses-proxy

##Usage

    ses_proxy [OPTIONS] SUBCOMMAND [ARGS] ...

    Subcommands:
        start                         Start proxy
        stop                          Stop proxy

###Start command

    ses_proxy start [OPTIONS]

    Options:
        -s, --smtp-port SMTP_PORT     SMTP listen port (default: "1025")
        -o, --smtp-host SMTP_HOST     SMTP host (default: "0.0.0.0")
        -p, --http-port HTTP_PORT     HTTP listen port (default: "9292")
        -l, --http-address HTTP_ADDRESS HTTP listen address (default: "0.0.0.0")
        -e, --environment ENVIRONMENT Environment (default: "development")
        -c, --config-file CONFIG_FILE Configuration file (default: "/home/user/.ses-proxy/ses-proxy.yml")
        -m, --mongoid-config-file MONGOID_CONFIG_FILE Mongoid configuration file (default: "/home/user/.ses-proxy/mongoid.yml")
        -d, --demonize                Demonize application (default: false)
        --pid-dir PID_DIR             Pid Directory (default: "/tmp")

When you start ses\_proxy for the first time, two configuration files will be created.
The first one is the configuration for MongoDB server (/home/user/.ses-proxy/mongoid.yml). You can edit it if your server runs on a different host.
The second one (/home/user/.ses-proxy/ses-proxy.yml) contains the general configuration for ses\_proxy. The available options are the following:

    :collect_sent_mails: true
    :collect_bounced_mails: true
    :blacklisted_domains:
      - domain1.ltd
      - domain2.ltd
    :blacklisted_regexp:
      - regexp1_pattern_without_delimiters
      - regexp2_pattern_without_delimiters
    :aws:
      :access_key_id: your_access_key_id
      :secret_access_key: your_secret_access_key
      :account_id: 000000000000
      :allowed_topic_arns: ["arn:aws:sns:us-east-1:123456789012:MyTopic"]
    :smtp_auth:
      :user: smtp_user
      :password: smtp_pass
    :http_auth:
      -
        :user: http_user_1
        :password: http_password_1
      -
        :user: http_user_2
        :password: http_password_2
    :test:
      :from: test@example.com
      :to: ["test@example.com"]
      :topic_arn: "arn:aws:sns:us-east-1:123456789012:MyTopic"
      :subscription_arn: "arn:aws:sns:us-east-1:123456789012:MyTopic:2bcfbf39-05c3-41de-beaa-fcfcc21c8f55"
    :smtp:
      :port: 1025
      :host: 0.0.0.0
    :http:
      :port: 9292
      :host: 0.0.0.0

The ":test" section is used just if you want contribute to the application development.

After starting ses\_proxy the first step is to setup your application to use the proxy as smtp server.
If your application is a Rails application, you can also use this gem [ses-proxy-rails](https://github.com/maintux/ses-proxy-rails).

Then you have to setup your SES bounce and complaint notifications through SNS (Simple Notification Service) with a subscription that has "http://yourhost:port/sns_endpoint/" as endpoint. For more details see [AWS Documentation](http://docs.aws.amazon.com/ses/latest/DeveloperGuide/ConfiguringNotificationsSNS.html)
This configuration allows ses-proxy to collect the email addresses which cause problems. When ses-proxy receives an email, checks if there are some blacklisted recipient, so as to be able to remove this addresses.

Moreover you can see all the blacklisted address and all sent mails through a easy web application that is located at "http://yourhost:port". The basic HTTP Authentication uses the credentials defined in :http_auth section in ses-proxy.yml file.

###Stop command

This command has effect only if you start ses\_proxy like a daemon.

##Contributing to ses-proxy

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

##License

(The MIT License)

Copyright (c) 2012 Massimo Maino

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.