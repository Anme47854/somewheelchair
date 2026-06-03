+1处理的异常，当时和蓝鲸的人沟通两天没查出原因

异常的人cmd上执行下tzutil /g这个命令，显示的应该不是China Standard Time
能够查看的应该是显示China Standard Time_dstoff或者其他的
然后执行tzutil /s "China Standard Time"
退出浏览器，重新登录就可以了
