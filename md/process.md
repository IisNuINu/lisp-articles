---
title: Потоки/нити(Threads)
---

<a name="intro"></a>

## Вступление

Под _threads_(потоками) мы подразумеваем отдельные нити выполнения в 
одном процессе Lisp, совместно использующие одно и то же адресное пространство. 
Как правило, выполнение автоматически переключается между этими нитями системой 
(либо ядром lisp, либо операционной системой), так что кажется, что задачи выполняются 
параллельно (асинхронно). На этой странице обсуждается создание потоков и 
управление ими, а также некоторые аспекты взаимодействия между ними. Для получения 
информации о взаимодействии между lisp и другими процессами см. 
[Взаимодействие с вашей ОС](os.html).

Моментальная ловушка для неосторожных людей заключается в том, что большинство 
реализаций ссылаются (в номенклатуре) на потоки как на _processes_ (процессы) 
- это историческая особенность языка, который существует гораздо дольше, 
чем термин _thread_ (поток). Если хотите, назовите эту зрелость признаком 
стабильных реализаций.

В стандарте ANSI Common Lisp эта тема не упоминается. Мы представим здесь 
переносимую библиотеку [bordeaux-threads](https://github.com/sionescu/bordeaux-threads), 
пример реализации через потоки SBCL - [SBCL threads](http://www.sbcl.org/manual/#Threading) 
из Руководства по SBCL - [SBCL Manual](http://www.sbcl.org/manual/) и библиотеку 
[lparallel](https://lparallel.org).

Bordeaux-thread - это де-факто стандартная переносимая библиотека, которая 
предоставляет довольно низкоуровневые примитивы. Lparallel основывается на 
нем и имеет следующие особенности: 

-  простая модель подчиненной задачи с очередью приема
-   конструкции для выражения мелкозернистого параллелизма
-  **асинхронная обработка условий** через границы потоков
-  **параллельные версии map, reduce, sort, remove** и многие другие
-  **promises**(обещания), futures(будущее) и конструкции отложенного выполнения
-  деревья вычислений для распараллеливания взаимосвязанных задач
-  ограниченные и неограниченные очереди - **queues** FIFO
-  каналы - **channels**
-  задачи с высоким и низким приоритетом
-  убийство задач по категориям
-  интегрированные таймауты

Дополнительные библиотеки по параллелизму и concurrency(одновременности) см. В 
[Awesome CL list](https://github.com/CodyReichert/awesome-cl#parallelism-and-concurrency), 
и [Quickdocs](http://quickdocs.org/) таких как quickdocks о [thread](https://quickdocs.org/-/search?q=thread) и [concurrency](https://quickdocs.org/-/search?q=concurrency).

<a name="why_bother"></a>

### Зачем возиться?

Первый вопрос, который нужно решить: зачем возиться с потоками? 
Иногда ваш ответ будет заключаться в том, что ваше приложение настолько прямолинейно, 
что вам вообще не нужно беспокоиться о потоках. Но во многих других случаях трудно 
представить, как можно написать сложное приложение без многопоточности. 
Например: 

*   вы можете писать сервер, который должен иметь возможность отвечать 
    более чем одному пользователю / соединению одновременно (например, 
    веб-сервер) на странице сокетов);
*   вы можете захотеть выполнить некоторую фоновую активность, не останавливая 
    при этом основное приложение;
*   вы можете захотеть, чтобы ваше приложение получало уведомление по истечении 
    определенного времени;
*   вы можете захотеть оставить приложение работающим и активным, пока не станет 
    доступен какой-либо системный ресурс;
*   вам может потребоваться взаимодействие с какой-либо другой системой, которая 
    требует многопоточности (например, "windows" под Windows, которые обычно 
    работают в своих собственных потоках);
*   вы можете захотеть связать разные контексты (например, разные динамические 
    привязки) с разными частями приложения;
*   у вас может даже возникнуть простая потребность сделать две вещи одновременно.

<a name="emergency"></a>

### Что такое одновременность(Concurrency)? Что такое параллелизм? 

*Credit: The following was first written on
[z0ltan.wordpress.com](https://z0ltan.wordpress.com/2016/09/02/basic-concurrency-and-parallelism-in-common-lisp-part-3-concurrency-using-bordeaux-and-sbcl-threads/)
by Timmy Jose.*

Одновременность(Concurrency) - это способ одновременного выполнения различных, 
возможно связанных задач. Это означает, что даже на однопроцессорной машине 
вы можете моделировать одновременность, используя потоки (например) и 
переключая их контекст.

В случае системных (родных ОС) потоков планирование и переключение контекста 
в конечном итоге определяется ОС. Так обстоит дело с потоками Java и потоками 
Common Lisp.

В случае  “green/зеленых” потоков, то есть потоков, полностью управляемых 
программой, планирование может полностью контролироваться самой программой. 
Erlang - отличный пример такого подхода. 

Так в чем же разница между одновременностью и параллелизмом? Параллелизм 
обычно определяется в очень строгом смысле как означающий, что независимые 
задачи выполняются параллельно, одновременно, на разных процессорах или 
на разных ядрах. В этом узком смысле параллелизма на одноядерной 
однопроцессорной машине быть не может.


Это скорее помогает различать эти две взаимосвязанные концепции на более 
абстрактном уровне - одновременность в первую очередь имеет дело с созданием 
иллюзии одновременности для клиентов, чтобы система не казалась заблокированной, 
когда выполняется длительная операция. Системы с графическим интерфейсом - 
прекрасный пример такого рода систем. Следовательно, одновременность связана 
с обеспечением хорошего взаимодействия с пользователем и не обязательно связана 
с повышением производительности.

Набор инструментов Java Swing и JavaScript являются однопоточными, и все же 
они могут создавать впечатление одновременности из-за скрытого переключения 
контекста. Конечно, в большинстве случаев параллелизм реализуется с 
использованием нескольких потоков / процессов. 

С другой стороны, параллелизм в основном связан с чистым увеличением 
производительности. Например, если нам дается задача найти квадраты всех 
четных чисел в заданном диапазоне, мы могли бы разделить диапазон на фрагменты, 
которые затем запускались параллельно на разных ядрах или разных процессорах, 
а затем результаты можно было сопоставить вместе, чтобы сформировать 
окончательный результат. Это пример Map-Reduce в действии.

Итак, теперь, когда мы отделили абстрактное значение одновременности от 
параллелизма, мы можем немного поговорить о реальном механизме, используемом 
для их реализации. Именно здесь у многих возникает большая путаница. Они 
склонны связывать абстрактные концепции с конкретными средствами их реализации. 
По сути, обе абстрактные концепции могут быть реализованы с использованием одних 
и тех же механизмов! Например, мы можем реализовать одновременные функции и 
параллельные функции, используя один и тот же базовый механизм потоков в Java. 
Только концептуальное переплетение или независимость задач на абстрактном уровне 
имеет значение для нас. 

Например, если у нас есть задача, в которой часть работы может быть выполнена 
в другом потоке (возможно, на другом ядре / процессоре), но поток, который
порождает этот поток, логически зависит от результатов порожденного потока 
(и как таковой должен join/присоединиться к этому потоку), это все еще одновременность!

Итак, суть в следующем: одновременность и параллелизм - это разные концепции, 
но их реализации могут выполняться с использованием одних и тех же механизмов 
- потоков, процессов и т.Д.

## Потоки Bordeaux

Библиотека Bordeaux предоставляет независимый от платформы способ 
обработки базовых потоков в нескольких реализациях Common Lisp. 
Интересно то, что она сама по себе не создает никаких собственных 
потоков - для этого она полностью полагается на базовую реализацию.

С другой стороны, он предоставляет некоторые полезные дополнительные 
функциональности в своих собственных абстракциях над потоками 
нижнего уровня.

Кроме того, вы можете видеть из демонстрационных программ, что многие 
функции Bordeaux кажутся очень похожими на те, которые используются 
в SBCL. Не думаю, что это совпадение.

Вы можете обратиться к документации для получения более подробной 
информации (см. Раздел «Подведение итогов»). 

### Установка потоков Bordeaux

Сначала загрузим библиотеку Bordeaux с помощью Quicklisp: 

~~~lisp
CL-USER> (ql:quickload "bt-semaphore")
To load "bt-semaphore":
  Load 1 ASDF system:
    bt-semaphore
; Loading "bt-semaphore"

(:BT-SEMAPHORE)
~~~

### Проверка поддержки потоков в Common Lisp 

Независимо от реализации Common Lisp существует стандартный способ проверить 
доступность поддержки потоков: 

~~~lisp
CL-USER> (member :thread-support *FEATURES*)
(:THREAD-SUPPORT :SWANK :QUICKLISP :ASDF-PACKAGE-SYSTEM :ASDF3.1 :ASDF3 :ASDF2
 :ASDF :OS-MACOSX :OS-UNIX :NON-BASE-CHARS-EXIST-P :ASDF-UNICODE :64-BIT
 :64-BIT-REGISTERS :ALIEN-CALLBACKS :ANSI-CL :ASH-RIGHT-VOPS :BSD
 :C-STACK-IS-CONTROL-STACK :COMMON-LISP :COMPARE-AND-SWAP-VOPS
 :COMPLEX-FLOAT-VOPS :CYCLE-COUNTER :DARWIN :DARWIN9-OR-BETTER :FLOAT-EQL-VOPS
 :FP-AND-PC-STANDARD-SAVE :GENCGC :IEEE-FLOATING-POINT :INLINE-CONSTANTS
 :INODE64 :INTEGER-EQL-VOP :LINKAGE-TABLE :LITTLE-ENDIAN
 :MACH-EXCEPTION-HANDLER :MACH-O :MEMORY-BARRIER-VOPS :MULTIPLY-HIGH-VOPS
 :OS-PROVIDES-BLKSIZE-T :OS-PROVIDES-DLADDR :OS-PROVIDES-DLOPEN
 :OS-PROVIDES-PUTWC :OS-PROVIDES-SUSECONDS-T :PACKAGE-LOCAL-NICKNAMES
 :PRECISE-ARG-COUNT-ERROR :RAW-INSTANCE-INIT-VOPS :SB-DOC :SB-EVAL :SB-LDB
 :SB-PACKAGE-LOCKS :SB-SIMD-PACK :SB-SOURCE-LOCATIONS :SB-TEST :SB-THREAD
 :SB-UNICODE :SBCL :STACK-ALLOCATABLE-CLOSURES :STACK-ALLOCATABLE-FIXED-OBJECTS
 :STACK-ALLOCATABLE-LISTS :STACK-ALLOCATABLE-VECTORS
 :STACK-GROWS-DOWNWARD-NOT-UPWARD :SYMBOL-INFO-VOPS :UD2-BREAKPOINTS :UNIX
 :UNWIND-TO-FRAME-AND-CALL-VOP :X86-64)
~~~

Если бы не было поддержки потока, в качестве значения выражения было бы показано “NIL”.


В зависимости от конкретной используемой библиотеки у нас также могут быть 
разные способы проверки поддержки одновременности(concurrency), которые могут 
использоваться вместо общей проверки, упомянутой выше.

Например, в нашем случае мы заинтересованы в использовании библиотеки 
Bordeaux. Чтобы проверить, есть ли поддержка потоков, использующих эту 
библиотеку, мы можем увидеть, установлено ли для глобальной переменной 
*supports-threads-p* значение NIL (нет поддержки) или T (поддержка доступна): 

~~~lisp
CL-USER> bt:*supports-threads-p*
T
~~~

Хорошо, теперь, когда мы разобрались с этим, давайте протестируем как 
платформо-независимую библиотеку (Bordeaux), так и поддержку конкретной платформы 
(в данном случае SBCL).

Для этого давайте рассмотрим несколько простых примеров: 

-    Основа - перечислить текущий поток, перечислить все потоки, получить имя потока
-    Обновить глобальную переменную из потока
-    Распечатать сообщение на верхнем уровне с используя поток
-    Печатать сообщение на верхнем уровне - исправлено
-    Распечатать сообщение на верхнем уровне - лучшее
-    Изменять общий ресурс из нескольких потоков
-    Изменение общего ресурса из нескольких потоков - с помощью блокировок исправлено
-    Изменить общий ресурс из нескольких потоков - используя атомарные операции
-    Присоединение к потоку, уничтожение примера потока 

### Основы - перечислить текущий поток, перечислить все потоки, получить имя потока 

~~~lisp
    ;;; Print the current thread, all the threads, and the current thread's name
    (defun print-thread-info ()
      (let* ((curr-thread (bt:current-thread))
             (curr-thread-name (bt:thread-name curr-thread))
             (all-threads (bt:all-threads)))
        (format t "Current thread: ~a~%~%" curr-thread)
        (format t "Current thread name: ~a~%~%" curr-thread-name)
        (format t "All threads:~% ~{~a~%~}~%" all-threads))
      nil)
~~~

И вывод: 

~~~lisp
    CL-USER> (print-thread-info)
    Current thread: #<THREAD "repl-thread" RUNNING {10043B8003}>

    Current thread name: repl-thread

    All threads:
     #<THREAD "repl-thread" RUNNING {10043B8003}>
    #<THREAD "auto-flush-thread" RUNNING {10043B7DA3}>
    #<THREAD "swank-indentation-cache-thread" waiting on: #<WAITQUEUE  {1003A28103}> {1003A201A3}>
    #<THREAD "reader-thread" RUNNING {1003A20063}>
    #<THREAD "control-thread" waiting on: #<WAITQUEUE  {1003A19E53}> {1003A18C83}>
    #<THREAD "Swank Sentinel" waiting on: #<WAITQUEUE  {1003790043}> {1003788023}>
    #<THREAD "main thread" RUNNING {1002991CE3}>

    NIL
~~~

Обновите глобальную переменную из потока: 

~~~lisp
    (defparameter *counter* 0)

    (defun test-update-global-variable ()
      (bt:make-thread
       (lambda ()
         (sleep 1)
         (incf *counter*)))
      *counter*)
~~~

Мы создаем новый поток, используя `bt:make-thread`, которая принимает в 
качестве параметра лямбда-абстракцию. Обратите внимание, что эта 
лямбда-абстракция не может принимать никаких параметров.

Еще один момент, который следует отметить, заключается в том, что в отличие 
от некоторых других языков (например, Java), нет разделения между созданием 
объекта потока и его запуском. В этом случае, как только поток создается, 
он сразу начинает выполнятся.

Вывод: 

~~~lisp
    CL-USER> (test-update-global-variable)

    0
    CL-USER> *counter*
    1
~~~

Как мы видим, поскольку основной поток вернулся немедленно, начальное 
значение *counter* равно 0, а примерно через секунду оно обновляется 
до 1 анонимным потоком.

### Создать поток: распечатывающий сообщение на верхнем уровне 

~~~lisp
    ;;; Print a message onto the top-level using a thread
    (defun print-message-top-level-wrong ()
      (bt:make-thread
       (lambda ()
         (format *standard-output* "Hello from thread!"))
       :name "hello")
      nil)
~~~

И вывод:

~~~lisp
    CL-USER> (print-message-top-level-wrong)
    NIL
~~~

Так что же пошло не так? Проблема в привязке переменных. Теперь параметр 
’t’ функции форматирования относится к верхнему уровню, который является 
термином Common Lisp для основного консольного потока, также на который 
ссылается глобальная переменная `*standard-output*`. Таким образом, мы 
могли ожидать, что вывод будет отображаться на главном экране консоли.

Тот же код работал бы нормально, если бы мы не запускали его в отдельном 
    потоке. Что происходит, так это то, что каждый поток имеет свой собственный 
    стек, в котором происходит повторное связывание переменных. В этом случае 
    даже для `*standard-output*`, который является глобальной переменной, 
    которая, как мы предполагаем, должна быть доступна для всех потоков,
    происходит пересвязывание внутри каждого потока! Это похоже на концепцию 
    хранилища ThreadLocal в Java. 
Распечатать сообщение на верхнем уровне - исправлено:

Итак, как нам исправить проблему из предыдущего примера? Конечно, путем привязки 
верхнего уровня во время создания потока. На помощь приходит чистая лексическая 
область видимости! 

~~~lisp
    ;;; Print a message onto the top-level using a thread â fixed
    (defun print-message-top-level-fixed ()
      (let ((top-level *standard-output*))
        (bt:make-thread
         (lambda ()
           (format top-level "Hello from thread!"))
         :name "hello")))
      nil)
~~~

Которая производит:

~~~lisp
    CL-USER> (print-message-top-level-fixed)
    Hello from thread!
    NIL
~~~

Уф! Однако есть еще один способ получить тот же результат с использованием 
очень интересного макроса для чтения, как мы увидим дальше.


### Распечатать сообщение на верхнем уровне - вычислением макроса во время чтения

Давайте сначала посмотрим на код: 

~~~lisp
    ;;; Print a message onto the top-level using a thread - reader macro

    (eval-when (:compile-toplevel)
      (defun print-message-top-level-reader-macro ()
        (bt:make-thread
         (lambda ()
           (format #.*standard-output* "Hello from thread!")))
        nil))

    (print-message-top-level-reader-macro)
~~~

И вывод: 

~~~lisp
    CL-USER> (print-message-top-level-reader-macro)
    Hello from thread!
    NIL
~~~

Итак, это работает, но в чем дело с eval-when и что это за странный  символ #. перед 
 `*standard-output*`?

eval-when контролирует, когда происходит вычисление выражений Лиспа. У нас может 
быть три цели - :compile-toplevel, :load-toplevel и :execute.

символ `#.`  - это то, что называется “макросом чтения“. Макрос чтения (или читатель) 
называется так, потому что он имеет особое значение для Считывателя(Reader) Common Lisp, 
который является компонентом, который отвечает за чтение выражений в Common Lisp и 
извлечение из них смысла. Этот конкретный макрос чтения гарантирует, что привязка 
`*standard-output*` выполняется во время чтения. 

Связывание значения во время чтения гарантирует, что исходное значение 
`*standard-output*` сохраняется при запуске потока, а вывод отображается 
на правильном верхнем уровне.

Теперь в игру вступает  eval-when. Оборачивая все определение функции 
внутри eval-when и обеспечивая выполнение вычисления во время компиляции, 
привязывается правильное значение `*standard-output*`. Если бы мы пропустили 
eval-when, то увидели бы следующую ошибку: 

~~~lisp
      error:
        don't know how to dump #<SWANK/GRAY::SLIME-OUTPUT-STREAM {100439EEA3}> (default MAKE-LOAD-FORM method called).
        ==>
          #<SWANK/GRAY::SLIME-OUTPUT-STREAM {100439EEA3}>

      note: The first argument never returns a value. 
      note:
        deleting unreachable code
        ==>
          "Hello from thread!"

    Compilation failed.
~~~

И это имеет смысл, потому что SBCL не может понять, что возвращает этот 
выходной поток, поскольку это поток, а не определенное значение 
(чего ожидает функция «format»). Поэтому мы видим ошибку 
«недостижимый код».


Обратите внимание, что если бы тот же код был запущен непосредственно 
в REPL, не было бы проблем, поскольку разрешение всех символов было 
бы выполнено правильно потоком REPL.

### Изменить общий ресурс из нескольких потоков

Предположим, у нас есть следующая настройка с минимальным классом 
bank-account(банковского счета) (без проверки ошибок): 

~~~lisp
    ;;; Modify a shared resource from multiple threads

    (defclass bank-account ()
      ((id :initarg :id
           :initform (error "id required")
           :accessor :id)
       (name :initarg :name
             :initform (error "name required")
             :accessor :name)
       (balance :initarg :balance
                :initform 0
                :accessor :balance)))

    (defgeneric deposit (account amount)
      (:documentation "Deposit money into the account"))

    (defgeneric withdraw (account amount)
      (:documentation "Withdraw amount from account"))

    (defmethod deposit ((account bank-account) (amount real))
      (incf (:balance account) amount))

    (defmethod withdraw ((account bank-account) (amount real))
      (decf (:balance account) amount))
~~~

И у нас есть простой клиент, который явно не верит ни в какие формы синхронизации: 

~~~lisp
    (defparameter *rich*
      (make-instance 'bank-account
                     :id 1
                     :name "Rich"
                     :balance 0))
    ; compiling (DEFPARAMETER *RICH* ...)

    (defun demo-race-condition ()
      (loop repeat 100
         do
           (bt:make-thread
            (lambda ()
              (loop repeat 10000 do (deposit *rich* 100))
              (loop repeat 10000 do (withdraw *rich* 100))))))
~~~

Это все, что мы делаем - создаем новый экземпляр банковского счета (balance
0), а затем создаем 100 потоков, каждый из которых просто вносит сумму 100 
10000 раз, а затем снимает ту же сумму такое же количество раз. Итак, 
конечный результат должен быть таким же, как и начальный баланс, который 
равен 0, верно? Давай проверим и посмотрим.

При пробном запуске мы можем получить следующие результаты: 

~~~lisp
    CL-USER> (:balance *rich*)
    0
    CL-USER> (dotimes (i 5)
               (demo-race-condition))
    NIL
    CL-USER> (:balance *rich*)
    22844600
~~~

Ого! Причина этого несоответствия в том, что incf и decf не являются 
атомарными операциями - они состоят из нескольких подопераций, и 
порядок, в котором они выполняются, не находится под нашим контролем.

Это то, что называется “состоянием состязания/гонки“ - несколько потоков 
конкурируют за один и тот же общий ресурс, по крайней мере, с одним 
модифицирующим потоком, который, скорее всего, считывает неправильное 
значение объекта при его изменении. Как это исправить? Один из простых 
способов - использовать блокировки (мьютекс в этом случае, и может быть 
семафором для более сложных ситуаций).



### Изменение общего ресурса из нескольких потоков - исправлено с помощью блокировок

Давайте сначала вернем баланс аккаунта в 0: 

~~~lisp
    CL-USER> (setf (:balance *rich*) 0)
    0
    CL-USER> (:balance *rich*)
    0
~~~

Теперь давайте изменим функцию demo-race-condition для доступа к общему ресурсу 
с помощью блокировок (созданных с помощью bt:make-lock и используемых, как показано): 

~~~lisp
    (defvar *lock* (bt:make-lock))
    ; compiling (DEFVAR *LOCK* â¦)

    (defun demo-race-condition-locks ()
      (loop repeat 100
         do
           (bt:make-thread
            (lambda ()
              (loop repeat 10000 do (bt:with-lock-held (*lock*)
                                      (deposit *rich* 100)))
              (loop repeat 10000 do (bt:with-lock-held (*lock*)
                                      (withdraw *rich* 100)))))))
    ; compiling (DEFUN DEMO-RACE-CONDITION-LOCKS ...)
~~~

И давайте на этот раз выполним более крупный прогон: 

~~~lisp
    CL-USER> (dotimes (i 100)
               (demo-race-condition-locks))
    NIL
    CL-USER> (:balance *rich*)
    0
~~~

Превосходно! Теперь это лучше. Конечно, нужно помнить, что использование 
такого мьютекса обязательно повлияет на производительность. В некоторых 
случаях есть лучший способ - использовать атомарные операции, когда это 
возможно. Мы поговорим об этом позже.



### Измените общий ресурс из нескольких потоков - используя атомарные операции

Атомарные операции - это операции, выполнение которых системой 
гарантируется внутри концептуальной транзакции, то есть все 
подоперации основной операции выполняются вместе без какого-либо 
вмешательства извне. Операция проходит полностью или 
полностью не выполняется. Нет золотой середины и нет 
противоречивого состояния. 

Еще одно преимущество состоит в том, что производительность намного 
превосходит использование блокировок для защиты доступа к общему состоянию. 
Мы увидим эту разницу в реальном демонстрационном запуске.

Библиотека Bordeaux не обеспечивает реальной поддержки атомарности, 
поэтому нам придется полагаться на конкретную поддержку реализации 
для этого. В нашем случае это SBCL, поэтому нам придется отложить эту 
демонстрацию до раздела SBCL.

### Присоединение к потоку, уничтожение потока

Чтобы присоединиться к потоку, мы используем функцию `bt:join-thread`, 
а для уничтожения потока (не рекомендуемая операция) мы можем 
использовать функцию `bt:destroy-thread`.


Простая демонстрация: 

~~~lisp
    (defmacro until (condition &body body)
      (let ((block-name (gensym)))
        `(block ,block-name
           (loop
               (if ,condition
                   (return-from ,block-name nil)
                   (progn
                       ,@body))))))

    (defun join-destroy-thread ()
      (let* ((s *standard-output*)
            (joiner-thread (bt:make-thread
                            (lambda ()
                              (loop for i from 1 to 10
                                 do
                                   (format s "~%[Joiner Thread]  Working...")
                                   (sleep (* 0.01 (random 100)))))))
            (destroyer-thread (bt:make-thread
                               (lambda ()
                                 (loop for i from 1 to 1000000
                                    do
                                      (format s "~%[Destroyer Thread] Working...")
                                      (sleep (* 0.01 (random 10000))))))))
        (format t "~%[Main Thread] Waiting on joiner thread...")
        (bt:join-thread joiner-thread)
        (format t "~%[Main Thread] Done waiting on joiner thread")
        (if (bt:thread-alive-p destroyer-thread)
            (progn
              (format t "~%[Main Thread] Destroyer thread alive... killing it")
              (bt:destroy-thread destroyer-thread))
            (format t "~%[Main Thread] Destroyer thread is already dead"))
        (until (bt:thread-alive-p destroyer-thread)
               (format t "[Main Thread] Waiting for destroyer thread to die..."))
        (format t "~%[Main Thread] Destroyer thread dead")
        (format t "~%[Main Thread] Adios!~%")))
~~~

И вывод при запуске: 

~~~lisp
    CL-USER> (join-destroy-thread)

    [Joiner Thread]  Working...
    [Destroyer Thread] Working...
    [Main Thread] Waiting on joiner thread...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Main Thread] Done waiting on joiner thread
    [Main Thread] Destroyer thread alive... killing it
    [Main Thread] Destroyer thread dead
    [Main Thread] Adios!
    NIL
~~~

Макрос until просто выполняет цикл, пока условие не станет истинным. 
Остальная часть кода в значительной степени не требует пояснений - 
основной поток ожидает завершения присоединяемого потока, но он 
немедленно уничтожает поток-разрушитель.

Опять же, не рекомендуется использовать `bt:destroy-thread`. Любая мыслимая 
ситуация, которая требует этой функции, вероятно, может быть лучше решена 
с помощью другого подхода.

Теперь давайте перейдем к более подробным примерам, которые объединяют 
все концепции, обсужденные до сих пор. 

### Полезные функции

Вот сводка функций, макросов и глобальных переменных, которые использовались 
в демонстрационных примерах, а также некоторые дополнения. Они должны 
охватывать большинство основных сценариев программирования: 

-    `bt:*supports-thread-p*` (для проверки базовой поддержки потоков)
-    `bt:make-thread` (создать новый поток)
-    `bt:current-thread` (вернуть объект текущего потока)
-    `bt:all-threads` (вернуть список всех запущенных потоков)
-    `bt:thread-alive-p` (проверяет, жив ли поток)
-    `bt:thread-name` (вернуть имя потока)
-    `bt:join-thread` (присоединиться к предоставленному потоку)
-    `bt:interrupt-thread` (прервать данный поток)
-    `bt:destroy-thread` (попытка прервать поток)
-    `bt:make-lock` (создать мьютекс)
-    `bt:with-lock-held` (используйте прилагаемый замок для защиты критического кода)

## Потоки SBCL


[SBCL](http://www.sbcl.org/) обеспечивает поддержку собственных потоков через 
свой пакет [sb-thread](http://www.sbcl.org/manual/#Threading). Это очень 
низкоуровневые функции, но мы можем создавать собственные абстракции на 
их основе, как показано в демонстрационных примерах.


Вы можете обратиться к документации для получения более подробной 
информации (см. Раздел «Wrap-up/Заключение»).


Из приведенных ниже примеров видно, что существует сильное соответствие 
между функциями Bordeaux и SBCL Thread. В большинстве случаев единственная 
разница заключается в изменении имени пакета с bt на sb-thread.


Очевидно, что библиотека потоков Bordeaux была более или менее основана 
на реализации SBCL. Таким образом, объяснение будет предоставлено только 
в тех случаях, когда есть существенные различия в синтаксисе или семантике. 

### Основы - перечислить текущий поток, перечислить все потоки, получить имя потока

Код:

~~~lisp
    ;;; Print the current thread, all the threads, and the current thread's name

    (defun print-thread-info ()
      (let* ((curr-thread sb-thread:*current-thread*)
             (curr-thread-name (sb-thread:thread-name curr-thread))
             (all-threads (sb-thread:list-all-threads)))
        (format t "Current thread: ~a~%~%" curr-thread)
        (format t "Current thread name: ~a~%~%" curr-thread-name)
        (format t "All threads:~% ~{~a~%~}~%" all-threads))
      nil)
~~~

И вывод: 

~~~lisp
    CL-USER> (print-thread-info)
    Current thread: #<THREAD "repl-thread" RUNNING {10043B8003}>

    Current thread name: repl-thread

    All threads:
     #<THREAD "repl-thread" RUNNING {10043B8003}>
    #<THREAD "auto-flush-thread" RUNNING {10043B7DA3}>
    #<THREAD "swank-indentation-cache-thread" waiting on: #<WAITQUEUE  {1003A28103}> {1003A201A3}>
    #<THREAD "reader-thread" RUNNING {1003A20063}>
    #<THREAD "control-thread" waiting on: #<WAITQUEUE  {1003A19E53}> {1003A18C83}>
    #<THREAD "Swank Sentinel" waiting on: #<WAITQUEUE  {1003790043}> {1003788023}>
    #<THREAD "main thread" RUNNING {1002991CE3}>

    NIL
~~~

### Обновить глобальную переменную из потока

Код: 

~~~lisp
    ;;; Update a global variable from a thread

    (defparameter *counter* 0)

    (defun test-update-global-variable ()
      (sb-thread:make-thread
       (lambda ()
         (sleep 1)
         (incf *counter*)))
      *counter*)
~~~

И вывод: 

~~~lisp
    CL-USER> (test-update-global-variable)
    0
~~~

### Распечатать сообщение на верхнем уровне используя поток

Код: 

~~~lisp
    ;;; Print a message onto the top-level using a thread

    (defun print-message-top-level-wrong ()
      (sb-thread:make-thread
       (lambda ()
         (format *standard-output* "Hello from thread!")))
      nil)
~~~

И вывод: 

~~~lisp
    CL-USER> (print-message-top-level-wrong)
    NIL
~~~

Распечатать сообщение на верхнем уровне - исправлено:


Код: 

~~~lisp
    ;;; Print a message onto the top-level using a thread - fixed

    (defun print-message-top-level-fixed ()
      (let ((top-level *standard-output*))
        (sb-thread:make-thread
         (lambda ()
           (format top-level "Hello from thread!"))))
      nil)
~~~

И вывод: 

~~~lisp
    CL-USER> (print-message-top-level-fixed)
    Hello from thread!
    NIL
~~~

### Распечатать сообщение на верхнем уровне - лучше

Код: 

~~~lisp
    ;;; Print a message onto the top-level using a thread - reader macro

    (eval-when (:compile-toplevel)
      (defun print-message-top-level-reader-macro ()
        (sb-thread:make-thread
         (lambda ()
           (format #.*standard-output* "Hello from thread!")))
        nil))
~~~

И вывод: 

~~~lisp
    CL-USER> (print-message-top-level-reader-macro)
    Hello from thread!
    NIL
~~~

###    Изменить общий ресурс из нескольких потоков 

Код:

~~~lisp
    ;;; Modify a shared resource from multiple threads

    (defclass bank-account ()
      ((id :initarg :id
           :initform (error "id required")
           :accessor :id)
       (name :initarg :name
             :initform (error "name required")
             :accessor :name)
       (balance :initarg :balance
                :initform 0
                :accessor :balance)))

    (defgeneric deposit (account amount)
      (:documentation "Deposit money into the account"))

    (defgeneric withdraw (account amount)
      (:documentation "Withdraw amount from account"))

    (defmethod deposit ((account bank-account) (amount real))
      (incf (:balance account) amount))

    (defmethod withdraw ((account bank-account) (amount real))
      (decf (:balance account) amount))

    (defparameter *rich*
      (make-instance 'bank-account
                     :id 1
                     :name "Rich"
                     :balance 0))

    (defun demo-race-condition ()
      (loop repeat 100
         do
           (sb-thread:make-thread
            (lambda ()
              (loop repeat 10000 do (deposit *rich* 100))
              (loop repeat 10000 do (withdraw *rich* 100))))))
~~~

И вывод:

~~~lisp
    CL-USER> (:balance *rich*)
    0
    CL-USER> (demo-race-condition)
    NIL
    CL-USER> (:balance *rich*)
    3987400
~~~

###    Изменение общего ресурса из нескольких потоков - исправлено с помощью блокировок


Код:

~~~lisp
    (defvar *lock* (sb-thread:make-mutex))

    (defun demo-race-condition-locks ()
      (loop repeat 100
         do
           (sb-thread:make-thread
            (lambda ()
              (loop repeat 10000 do (sb-thread:with-mutex (*lock*)
                                      (deposit *rich* 100)))
              (loop repeat 10000 do (sb-thread:with-mutex (*lock*)
                                      (withdraw *rich* 100)))))))
~~~

Единственная разница здесь в том, что вместо make-lock, как в Bordeaux, 
у нас есть make-mutex, который используется вместе с макросом with-mutex, 
как показано в примере.

И вывод:

~~~lisp
    CL-USER> (:balance *rich*)
    0
    CL-USER> (demo-race-condition-locks)
    NIL
    CL-USER> (:balance *rich*)
    0
~~~

### Измените общий ресурс из нескольких потоков - используя атомарные операции


Первый, код:

~~~lisp
    ;;; Modify a shared resource from multiple threads - atomics

    (defgeneric atomic-deposit (account amount)
      (:documentation "Atomic version of the deposit method"))

    (defgeneric atomic-withdraw (account amount)
      (:documentation "Atomic version of the withdraw method"))

    (defmethod atomic-deposit ((account bank-account) (amount real))
      (sb-ext:atomic-incf (car (cons (:balance account) nil)) amount))

    (defmethod atomic-withdraw ((account bank-account) (amount real))
      (sb-ext:atomic-decf (car (cons (:balance account) nil)) amount))

    (defun demo-race-condition-atomics ()
      (loop repeat 100
         do (sb-thread:make-thread
             (lambda ()
               (loop repeat 10000 do (atomic-deposit *rich* 100))
               (loop repeat 10000 do (atomic-withdraw *rich* 100))))))
~~~

И вывод:

~~~lisp
    CL-USER> (dotimes (i 5)
               (format t "~%Opening: ~d" (:balance *rich*))
               (demo-race-condition-atomics)
               (format t "~%Closing: ~d~%" (:balance *rich*)))

    Opening: 0
    Closing: 0

    Opening: 0
    Closing: 0

    Opening: 0
    Closing: 0

    Opening: 0
    Closing: 0

    Opening: 0
    Closing: 0
    NIL
~~~

Как видите, атомарные функции SBCL несколько необычны. Две используемые 
здесь функции: `sb-ext:incf` и `sb-ext:atomic-decf` имеют следующие 
сигнатуры: 

    Macro: atomic-incf [sb-ext] place &optional diff

и

    Macro: atomic-decf [sb-ext] place &optional diff

Интересно то, что параметр «place/место» должен иметь одно из следующих 
значений (согласно документации):


- слот defstruct с объявленным типом (unsigned-byte 64) или aref из 
(simple-array (unsigned-byte 64) (*)) Для этих целей можно использовать 
тип `sb-ext:word`.
- car или cdr (соответственно first или REST) для cons.
-   переменная, определенная с помощью defglobal с заявленным типом
(proclaimed type) fixnum

Это причина причудливой конструкции, используемой в методах 
`atomic-deposit` и `atomic-decf`.


Одним из основных стимулов максимально использовать атомарные операции 
является производительность. Давайте быстро запустим функции 
demo-race-condition-locks и demo-race-condition-atomics более 1000 раз 
и проверим разницу в производительности (если есть):

С блокировками:

~~~lisp
    CL-USER> (time
                        (loop repeat 100
                          do (demo-race-condition-locks)))
    Evaluation took:
      57.711 seconds of real time
      431.451639 seconds of total run time (408.014746 user, 23.436893 system)
      747.61% CPU
      126,674,011,941 processor cycles
      3,329,504 bytes consed

    NIL
~~~

С атомарными операциями:

~~~lisp
    CL-USER> (time
                        (loop repeat 100
                         do (demo-race-condition-atomics)))
    Evaluation took:
      2.495 seconds of real time
      8.175454 seconds of total run time (6.124259 user, 2.051195 system)
      [ Run times consist of 0.420 seconds GC time, and 7.756 seconds non-GC time. ]
      327.66% CPU
      5,477,039,706 processor cycles
      3,201,582,368 bytes consed

    NIL
~~~

Результаты? Версия с блокировками заняла около 57 с, тогда как 
версия без блокировки с атомикой заняла всего 2 с! Это действительно 
огромная разница!

### Присоединение к потоку, уничтожение примера потока


Код:

~~~lisp
    ;;; Joining on and destroying a thread

    (defmacro until (condition &body body)
      (let ((block-name (gensym)))
        `(block ,block-name
           (loop
               (if ,condition
                   (return-from ,block-name nil)
                   (progn
                       ,@body))))))

    (defun join-destroy-thread ()
      (let* ((s *standard-output*)
            (joiner-thread (sb-thread:make-thread
                            (lambda ()
                              (loop for i from 1 to 10
                                 do
                                   (format s "~%[Joiner Thread]  Working...")
                                   (sleep (* 0.01 (random 100)))))))
            (destroyer-thread (sb-thread:make-thread
                               (lambda ()
                                 (loop for i from 1 to 1000000
                                    do
                                      (format s "~%[Destroyer Thread] Working...")
                                      (sleep (* 0.01 (random 10000))))))))
        (format t "~%[Main Thread] Waiting on joiner thread...")
        (bt:join-thread joiner-thread)
        (format t "~%[Main Thread] Done waiting on joiner thread")
        (if (sb-thread:thread-alive-p destroyer-thread)
            (progn
              (format t "~%[Main Thread] Destroyer thread alive... killing it")
              (sb-thread:terminate-thread destroyer-thread))
            (format t "~%[Main Thread] Destroyer thread is already dead"))
        (until (sb-thread:thread-alive-p destroyer-thread)
               (format t "[Main Thread] Waiting for destroyer thread to die..."))
        (format t "~%[Main Thread] Destroyer thread dead")
        (format t "~%[Main Thread] Adios!~%")))
~~~

И вывод:

~~~lisp
    CL-USER> (join-destroy-thread)

    [Joiner Thread]  Working...
    [Destroyer Thread] Working...
    [Main Thread] Waiting on joiner thread...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Joiner Thread]  Working...
    [Main Thread] Done waiting on joiner thread
    [Main Thread] Destroyer thread alive... killing it
    [Main Thread] Destroyer thread dead
    [Main Thread] Adios!
    NIL
~~~

### Полезные функции

Вот краткий список функций, макросов и глобальных переменных, 
используемых в примерах, а также некоторые дополнения:

-    `(member :thread-support *features*)` (проверка поддержки потоков)
-    `sb-thread:make-thread` (создать новый поток)
-    `sb-thread:*current-thread*` (содержит объект текущего потока)
-    `sb-thread:list-all-threads` (вернуть список всех запущенных потоков)
-    `sb-thread:thread-alive-p` (проверяет, жив ли поток)
-    `sb-thread:thread-name` (вернуть имя потока)
-    `sb-thread:join-thread` (присоединиться к предоставленному потоку)
-    `sb-thread:interrupt-thread` (прервать данный поток)
-    `sb-thread:destroy-thread` (попытка уничтожить поток)
-    `sb-thread:make-mutex` (создать мьютекс)
-    `sb-thread:with-mutex` (используйте прилагаемую блокировку для защиты критического кода)

## краткая сводка новостей
	



Как видите, поддержка параллелизма в Common Lisp довольно примитивна, 
но в первую очередь это связано с явным отсутствием этой важной функции 
в спецификации ANSI Common Lisp. Это нисколько не умаляет ни поддержки, 
предоставляемой реализациями Common Lisp, ни замечательных библиотек, 
таких как библиотека Bordeaux.


Вам следует продолжить работу самостоятельно, прочитав еще много информации 
по этой теме. Я поделюсь некоторыми своими ссылками здесь: 

-    [Common Lisp Recipes](http://weitz.de/cl-recipes/)
-    [Bordeaux API Reference](https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation)
-    [SBCL Manual](http://www.sbcl.org/manual/) on [Threading](http://www.sbcl.org/manual/#Threading) 
-    [The Common Lisp Hyperspec](https://www.lispworks.com/documentation/HyperSpec/Front/)

Далее, последний пост в этой мини-серии: параллелизм в Common Lisp 
с использованием библиотеки **lparallel**.

## Параллельное программирование с lparallel

Важно отметить, что lparallel также обеспечивает обширную поддержку 
асинхронного программирования и не является чисто параллельной библиотекой 
программирования. Как указывалось ранее, параллелизм - это просто абстрактное 
понятие, в котором задачи концептуально независимы друг от друга.

Библиотека lparallel построена на основе библиотеки потоков Bordeaux. 

Как упоминалось ранее, параллелизм и одновременность могут быть 
(и обычно реализуются) с использованием одних и тех же средств 
- потоков, процессов и т. Д. Разница между ними заключается в 
их концептуальных различиях.

Обратите внимание, что не все примеры, показанные в этом посте, 
обязательно параллельны. Асинхронные конструкции, такие как 
Promises и Futures, в частности, больше подходят для параллельного 
программирования, чем для параллельного программирования.

Порядок работы(modus operandi) с библиотекой lparallel (для базового варианта использования)
выглядит следующим образом: 

- Создайте экземпляр того, что библиотека называет ядром(kernel), используя 
  `lparallel:make-kernel`. Ядро - это компонент, который планирует и выполняет 
   задачи.
-    Разработайте код в терминах будущего(futures), обещаний(promises) и 
     других функциональных концепций более высокого уровня. С этой целью 
     lparallel обеспечивает поддержку **channels**(каналов), **promises**(обещаний), 
     **futures**(будущее) и **cognates**(родственных).
-    Выполняйте операции, используя то, что библиотека называет родственными(cognates) 
     функциями, то есть просто функциями, имеющими эквиваленты в самом языке Common Lisp.
     Например, функция `lparallel:pmap` является параллельным эквивалентом 
     функции `map` Common Lisp.
-    Наконец, закройте ядро, созданное на первом шаге, с помощью `lparallel:end-kernel`.

Обратите внимание, что ответственность за логическую параллелизацию 
выполняемых задач и заботу обо всех изменяемых состояниях лежит на 
разработчике. 

_Credit: this article first appeared on
[z0ltan.wordpress.com](https://z0ltan.wordpress.com/2016/09/09/basic-concurrency-and-parallelism-in-common-lisp-part-4a-parallelism-using-lparallel-fundamentals/)._

### Установка

Давайте проверим, доступен ли lparallel для загрузки с помощью Quicklisp: 

~~~lisp
CL-USER> (ql:system-apropos "lparallel")
#<SYSTEM lparallel / lparallel-20160825-git / quicklisp 2016-08-25>
#<SYSTEM lparallel-bench / lparallel-20160825-git / quicklisp 2016-08-25>
#<SYSTEM lparallel-test / lparallel-20160825-git / quicklisp 2016-08-25>
; No value
~~~

Похоже, это так. Давайте продолжим и установим его: 

~~~lisp
CL-USER> (ql:quickload "lparallel")
To load "lparallel":
  Load 2 ASDF systems:
    alexandria bordeaux-threads
  Install 1 Quicklisp release:
    lparallel
; Fetching #<URL "http://beta.quicklisp.org/archive/lparallel/2016-08-25/lparallel-20160825-git.tgz">
; 76.71KB
==================================================
78,551 bytes in 0.62 seconds (124.33KB/sec)
; Loading "lparallel"
[package lparallel.util]..........................
[package lparallel.thread-util]...................
[package lparallel.raw-queue].....................
[package lparallel.cons-queue]....................
[package lparallel.vector-queue]..................
[package lparallel.queue].........................
[package lparallel.counter].......................
[package lparallel.spin-queue]....................
[package lparallel.kernel]........................
[package lparallel.kernel-util]...................
[package lparallel.promise].......................
[package lparallel.ptree].........................
[package lparallel.slet]..........................
[package lparallel.defpun]........................
[package lparallel.cognate].......................
[package lparallel]
(:LPARALLEL)
~~~

И это все, что нужно! Теперь посмотрим, как на самом деле работает эта библиотека.

### Преамбула - получить количество ядер


Во-первых, давайте определим количество потоков, которые мы собираемся 
использовать для наших параллельных примеров. В идеале мы хотели бы иметь 
соответствие 1: 1 между количеством рабочих потоков и количеством доступных 
ядер(cores).

Для этого мы можем использовать замечательную библиотеку **Serapeum**, 
которая имеет функцию `count-cpus`, которая работает на всех
основных платформах.

Установите её: 

~~~lisp
CL-USER> (ql:quickload "serapeum")
~~~

и назови это: 

~~~lisp
CL-USER> (serapeum:count-cpus)
8
~~~

и проверьте, что это правильно. 

### Общая настройка

В этом примере мы рассмотрим часть начальной настройки, а также покажем 
некоторую полезную информацию после завершения настройки.

Загрузите библиотеку: 

~~~lisp
CL-USER> (ql:quickload "lparallel")
To load "lparallel":
  Load 1 ASDF system:
    lparallel
; Loading "lparallel"

(:LPARALLEL)
~~~

Инициализировать lparallel ядро:

~~~lisp
CL-USER> (setf lparallel:*kernel* (lparallel:make-kernel 8 :name "custom-kernel"))
#<LPARALLEL.KERNEL:KERNEL :NAME "custom-kernel" :WORKER-COUNT 8 :USE-CALLER NIL :ALIVE T :SPIN-COUNT 2000 {1003141F03}>
~~~

Обратите внимание, что глобальная переменная `*kernel*` может быть 
повторно связана - это позволяет нескольким ядрам сосуществовать 
во время одного запуска. Теперь немного полезной информации о ядре: 

~~~lisp
CL-USER> (defun show-kernel-info ()
           (let ((name (lparallel:kernel-name))
                 (count (lparallel:kernel-worker-count))
                 (context (lparallel:kernel-context))
                 (bindings (lparallel:kernel-bindings)))
             (format t "Kernel name = ~a~%" name)
             (format t "Worker threads count = ~d~%" count)
             (format t "Kernel context = ~a~%" context)
             (format t "Kernel bindings = ~a~%" bindings)))

WARNING: redefining COMMON-LISP-USER::SHOW-KERNEL-INFO in DEFUN
SHOW-KERNEL-INFO

CL-USER> (show-kernel-info)
Kernel name = custom-kernel
Worker threads count = 8
Kernel context = #<FUNCTION FUNCALL>
Kernel bindings = ((*STANDARD-OUTPUT* . #<SLIME-OUTPUT-STREAM {10044EEEA3}>)
                   (*ERROR-OUTPUT* . #<SLIME-OUTPUT-STREAM {10044EEEA3}>))
NIL
~~~

Завершения ядра (это важно, поскольку `*kernel*`(ядро) не собирает мусор,
пока мы явно не завершим его): 

~~~lisp
CL-USER> (lparallel:end-kernel :wait t)
(#<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {100723FA83}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {100723FE23}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {10072581E3}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {1007258583}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {1007258923}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {1007258CC3}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {1007259063}>
 #<SB-THREAD:THREAD "custom--kernel" FINISHED values: NIL {1007259403}>)
~~~

Давайте перейдем к еще нескольким примерам различных аспектов библиотеки lparallel.


Для этих демонстраций мы будем использовать следующую начальную настройку 
с точки зрения кодирования: 

~~~lisp
(require ‘lparallel)
(require ‘bt-semaphore)

(defpackage :lparallel-user
  (:use :cl :lparallel :lparallel.queue :bt-semaphore))

(in-package :lparallel-user)

;;; initialise the kernel
(defun init ()
  (setf *kernel* (make-kernel 8 :name "channel-queue-kernel")))

(init)
~~~

Таким образом, мы будем использовать ядро с 8 рабочими потоками (по одному 
на каждое ядро процессора на машине).


И как только мы закончим со всеми примерами, будет запущен следующий код, 
чтобы закрыть ядро и освободить все используемые системные ресурсы: 

~~~lisp
;;; shut the kernel down
(defun shutdown ()
  (end-kernel :wait t))

(shutdown)
~~~

### Использование каналов и очередей

Сначала несколько определений.


**task**(Задача) - это задание, которое передается ядру. Это просто 
объект функция вместе со своими аргументами.

**channel**(Канал) в lparallel аналогичен той же концепции в Go. Канал - 
это просто средство связи с рабочим потоком. В нашем случае это один 
из способов отправки задач ядру. 

Канал создается в lparallel с помощью `lparallel:make-channel`. 
Задача отправляется с помощью `lparallel:submit-task`, а результаты 
получаются с помощью `lparallel:receive-result`.


Например, мы можем вычислить квадрат числа как: 

~~~lisp
(defun calculate-square (n)
  (let* ((channel (lparallel:make-channel))
         (res nil))
    (lparallel:submit-task channel #'(lambda (x)
                                       (* x x))
                           n)
    (setf res (lparallel:receive-result channel))
    (format t "Square of ~d = ~d~%" n res)))
~~~

И вывод:

~~~lisp
LPARALLEL-USER> (calculate-square 100)
Square of 100 = 10000
NIL
~~~

Теперь давайте попробуем отправить несколько задач в один канал. В этом 
простом примере мы просто создаем три задачи, которые возводят в квадрат, 
по три и по четыре раза соответственно для предоставленных входных данных.

Обратите внимание, что в случае нескольких задач вывод будет в 
недетерминированном порядке: 

~~~lisp
(defun test-basic-channel-multiple-tasks ()
  (let ((channel (make-channel))
        (res '()))
    (submit-task channel #'(lambda (x)
                             (* x x))
                 10)
    (submit-task channel #'(lambda (y)
                             (* y y y))
                 10)
    (submit-task channel #'(lambda (z)
                             (* z z z z))
                 10)
     (dotimes (i 3 res)
       (push (receive-result channel) res))))
~~~

И вывод:

~~~lisp
LPARALLEL-USER> (dotimes (i 3)
                              (print (test-basic-channel-multiple-tasks)))

(100 1000 10000)
(100 1000 10000)
(10000 1000 100)
NIL
~~~

lparallel также обеспечивает поддержку для создания блокирующей очереди , 
чтобы разрешить передачу сообщений между рабочими потоками. Очередь 
создается с помощью `lparallel.queue:make-queue`.

Некоторые полезные функции для использования очередей:


-    `lparallel.queue:make-queue`: создает FIFO блокирующую очередь(blocking queue)
-    `lparallel.queue:push-queue`: вставляет элемент в очередь
-    `lparallel.queue:pop-queue`: извлекает элемент из очереди
-    `lparallel.queue:peek-queue`: проверяет значение без его извлечения из очереди
-    `lparallel.queue:queue-count`: количество записей в очереди
-    `lparallel.queue:queue-full-p`: проверить, заполнена ли очередь
-    `lparallel.queue:queue-empty-p`: проверить, пуста ли очередь
-    `lparallel.queue:with-locked-queue`: заблокировать очередь во время доступа

Базовая демонстрация, показывающая основные свойства очереди: 

~~~lisp
    (defun test-queue-properties ()
      (let ((queue (make-queue :fixed-capacity 5)))
        (loop
           when (queue-full-p queue)
           do (return)
           do (push-queue (random 100) queue))
         (print (queue-full-p queue))
        (loop
           when (queue-empty-p queue)
           do (return)
           do (print (pop-queue queue)))
        (print (queue-empty-p queue)))
      nil)
~~~

Что производит:

~~~lisp
    LPARALLEL-USER> (test-queue-properties)

    T
    17
    51
    55
    42
    82
    T
    NIL
~~~

Примечание: `lparallel.queue:make-queue` - это обобщенный интерфейс, который 
фактически поддерживается разными типами очередей. Например, в предыдущем 
примере фактическим типом очереди является `lparallel.vector-queue`, 
поскольку мы указали, что она имеет фиксированный размер, используя аргумент 
ключевого слова `:fixed-capacity`.

В документации фактически не указано, какие ключевые аргументы мы можем 
передать в `lparallel.queue:make-queue`, поэтому давайте выясним это 
другим способом: 

~~~lisp
    LPARALLEL-USER> (describe 'lparallel.queue:make-queue)
    LPARALLEL.QUEUE:MAKE-QUEUE
      [symbol]

    MAKE-QUEUE names a compiled function:
      Lambda-list: (&REST ARGS)
      Derived type: FUNCTION
      Documentation:
        Create a queue.

        The queue contents may be initialized with the keyword argument
        `initial-contents'.

        By default there is no limit on the queue capacity. Passing a
        `fixed-capacity' keyword argument limits the capacity to the value
        passed. `push-queue' will block for a full fixed-capacity queue.
      Source file: /Users/z0ltan/quicklisp/dists/quicklisp/software/lparallel-20160825-git/src/queue.lisp

    MAKE-QUEUE has a compiler-macro:
      Source file: /Users/z0ltan/quicklisp/dists/quicklisp/software/lparallel-20160825-git/src/queue.lisp
    ; No value
~~~

Итак, как мы видим, она поддерживает следующие аргументы ключевого слова:
*:fixed-capacity* и *initial-contents*.

Теперь, если мы укажем: `:fixed-capacity`, тогда фактическим типом 
очереди будет `lparallel.vector-queue`, и если мы пропустим этот 
аргумент ключевого слова, очередь будет иметь тип 
`lparallel.cons-queue` (который является очередью неограниченного 
размера), как видно из вывода следующего фрагмента: 

~~~lisp
    (defun check-queue-types ()
      (let ((queue-one (make-queue :fixed-capacity 5))
            (queue-two (make-queue)))
        (format t "queue-one is of type: ~a~%" (type-of queue-one))
        (format t "queue-two is of type: ~a~%" (type-of queue-two))))

    LPARALLEL-USER> (check-queue-types)
    queue-one is of type: VECTOR-QUEUE
    queue-two is of type: CONS-QUEUE
    NIL
~~~

Конечно, вы всегда можете создавать экземпляры определенных типов 
очередей самостоятельно, но всегда лучше, когда это возможно, 
придерживаться общего интерфейса и позволить библиотеке создать 
для вас правильный тип очереди.

А теперь давайте просто посмотрим, как работает очередь! 

~~~lisp
    (defun test-basic-queue ()
      (let ((queue (make-queue))
            (channel (make-channel))
            (res '()))
        (submit-task channel #'(lambda ()
                         (loop for entry = (pop-queue queue)
                            when (queue-empty-p queue)
                            do (return)
                            do (push (* entry entry) res))))
        (dotimes (i 100)
          (push-queue i queue))
        (receive-result channel)
        (format t "~{~d ~}~%" res)))
~~~

Здесь мы отправляем одну задачу, которая многократно сканирует очередь 
до тех пор, пока она не станет пустой, достает доступные значения и помещает 
их в список res.

И вывод:

~~~lisp
    LPARALLEL-USER> (test-basic-queue)
    9604 9409 9216 9025 8836 8649 8464 8281 8100 7921 7744 7569 7396 7225 7056 6889 6724 6561 6400 6241 6084 5929 5776 5625 5476 5329 5184 5041 4900 4761 4624 4489 4356 4225 4096 3969 3844 3721 3600 3481 3364 3249 3136 3025 2916 2809 2704 2601 2500 2401 2304 2209 2116 2025 1936 1849 1764 1681 1600 1521 1444 1369 1296 1225 1156 1089 1024 961 900 841 784 729 676 625 576 529 484 441 400 361 324 289 256 225 196 169 144 121 100 81 64 49 36 25 16 9 4 1 0
    NIL
~~~

###    Уничтожение задач

Небольшая заметка, в которой упоминается функция `lparallel:kill-task`, 
была бы уместна на данном этапе. Эта функция полезна в тех случаях, 
когда задачи не отвечают. В документации lparallel четко указано, 
что это следует использовать только в крайнем случае.




Всем созданным задачам по умолчанию присваивается категория :default. 
Динамическое свойство `*task-category*` содержит это значение и может
быть динамически привязано к различным значениям (как мы увидим). 

~~~lisp
;;; kill default tasks
(defun test-kill-all-tasks ()
  (let ((channel (make-channel))
        (stream *query-io*))
    (dotimes (i 10)
      (submit-task channel #'(lambda (x)
                               (sleep (random 10))
                               (format stream "~d~%" (* x x))) (random 10)))
    (sleep (random 2))
    (kill-tasks :default)))
~~~

Пример запуска:

~~~lisp
LPARALLEL-USER> (test-kill-all-tasks)
16
1
8
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
~~~

Поскольку мы создали 10 задач, все 8 рабочих потоков ядра предположительно 
были заняты каждой задачей. Когда мы убивали задачи категории :default, 
все эти потоки также были убиты, и их нужно было регенерировать 
(что является дорогостоящей операцией). Это одна из причин, по которой 
следует избегать `lparallel:kill-tasks`.

Теперь, в приведенном выше примере, все запущенные задачи были убиты, 
поскольку все они принадлежали к категории :default. Предположим, 
мы хотим убить только определенные задачи, мы можем сделать это, 
привязав `*task-category*` при создании этих задач, а затем указав 
категорию при вызове `lparallel:kill-tasks`.

Например, предположим, что у нас есть две категории задач - задачи, которые 
возводят в квадрат свои аргументы, и задачи, которые возводят в куб свои. 
Давайте назначим им категории "squaring-tasks" и "cubing-tasks" соответственно. 
Затем давайте уберем задачи из случайно выбранной категории: squaring-tasks 
или cubing-tasks.


Вот код: 

~~~lisp
;;; kill tasks of a randomly chosen category
(defun test-kill-random-tasks ()
  (let ((channel (make-channel))
        (stream *query-io*))
    (let ((*task-category* 'squaring-tasks))
      (dotimes (i 5)
        (submit-task channel #'(lambda (x)
                                 (sleep (random 5))
                                 (format stream "~%[Squaring] ~d = ~d" x (* x x))) i)))
    (let ((*task-category* 'cubing-tasks))
      (dotimes (i 5)
        (submit-task channel #'(lambda (x)
                                 (sleep (random 5))
                                 (format stream "~%[Cubing] ~d = ~d" x (* x x x))) i)))
    (sleep 1)
    (if (evenp (random 10))
        (progn
          (print "Killing squaring tasks")
          (kill-tasks 'squaring-tasks))
        (progn
          (print "Killing cubing tasks")
          (kill-tasks 'cubing-tasks)))))
~~~

А вот пример запуска: 

~~~lisp
LPARALLEL-USER> (test-kill-random-tasks)

[Cubing] 2 = 8
[Squaring] 4 = 16
[Cubing] 4
 = [Cubing] 643 = 27
"Killing squaring tasks"
4
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.

[Cubing] 1 = 1
[Cubing] 0 = 0

LPARALLEL-USER> (test-kill-random-tasks)

[Squaring] 1 = 1
[Squaring] 3 = 9
"Killing cubing tasks"
5
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.

[Squaring] 2 = 4
WARNING: lparallel: Replacing lost or dead worker.
WARNING: lparallel: Replacing lost or dead worker.

[Squaring] 0 = 0
[Squaring] 4 = 16
~~~

### Использование обещаний и будущих 

Promises(обещения) и Futures(будущее) обеспечивают поддержку 
асинхронного программирования. 

В lparallel-speak `lparallel:promise` является заполнителем для 
результата, который достигается путем предоставления ему значения. 
Сам объект promise(обещания) создается с помощью `lparallel:promise`, 
а обещанию присваивается значение с помощью макроса `lparallel:fulfill`.

Чтобы проверить, выполнено ли promise(обещание) или нет, мы можем 
использовать функцию предикат `lparallel:fulfilledp`. Наконец, функция 
`lparallel:force` используется для извлечения значения из обещания(promise). 
Обратите внимание, что эта функция блокируется до завершения операции.

Давайте сначала закрепим эти концепции на очень простом примере: 

~~~lisp
(defun test-promise ()
  (let ((p (promise)))
    (loop
       do (if (evenp (read))
              (progn
                (fulfill p 'even-received!)
                (return))))
    (force p)))
~~~

Что генерирует вывод :

~~~lisp
LPARALLEL-USER> (test-promise)
5
1
3
10
EVEN-RECEIVED!
~~~

Объяснение: В этом простом примере цикл продолжается бесконечно, пока не 
будет введено четное число. Обещание(promise) выполняется внутри цикла 
с помощью `lparallel:fulfill`, а затем значение возвращается из функции 
путем принудительного выполнения с помощью `lparallel:force`.

А теперь давайте рассмотрим более крупный пример. Предполагая, что мы не хотим, 
чтобы нам приходилось ждать выполнения обещания, а вместо этого чтобы текущий 
выполнял некоторую полезную работу, мы можем явно делегировать выполнение 
обещания внешнему, как показано в следующем примере.


Предположим, у нас есть функция, которая возводит в квадрат свой аргумент. 
И, ради аргумента, на это уходит много времени. Из нашего клиентского кода 
мы хотим вызвать его и подождать, пока не станет доступно значение в квадрате. 

~~~lisp
(defun promise-with-threads ()
  (let ((p (promise))
        (stream *query-io*)
        (n (progn
             (princ "Enter a number: ")
             (read))))
    (format t "In main function...~%")
    (bt:make-thread
     #'(lambda ()
         (sleep (random 10))
         (format stream "Inside thread... fulfilling promise~%")
         (fulfill p (* n n))))
    (bt:make-thread
     #'(lambda ()
         (loop
            when (fulfilledp p)
            do (return)
            do (progn
                 (format stream "~d~%" (random 100))
                 (sleep (* 0.01 (random 100)))))))
    (format t "Inside main function, received value: ~d~%" (force p))))
~~~

И вывод:

~~~lisp
LPARALLEL-USER> (promise-with-threads)
Enter a number: 19
In main function...
44
59
90
34
30
76
Inside thread... fulfilling promise
Inside main function, received value: 361
NIL
~~~

Пояснение: В этом примере нет ничего особенного. Мы создаем объект 
обещания(promise) p и порождаем поток, который спит в течение 
некоторого случайного времени, а затем выполняет обещание, 
присваивая ему значение.


Между тем, в основном потоке мы порождаем другой поток, который продолжает 
проверять, выполнено ли обещание или нет. Если нет, он печатает какое-то 
случайное число и продолжает проверку. Как только обещание выполнено, 
мы можем извлечь значение с помощью `lparallel:force` в основном потоке, 
как показано.

Это показывает, что обещания могут выполняться разными потоками, в то 
время как код, создавший обещание, не должен ждать выполнения обещания. 
Это особенно важно, поскольку, как упоминалось ранее, `lparallel:force` 
является блокирующим вызовом. Мы хотим отложить принудительное выполнение 
обещания до тех пор, пока значение не станет доступным.


Еще один момент, на который следует обратить внимание при использовании 
обещаний, заключается в том, что после выполнения обещания применение 
силы к одному и тому же объекту всегда будет возвращать одно и то же 
значение. То есть обещание может быть успешно выполнено только один раз.

Например: 

~~~lisp
(defun multiple-fulfilling ()
  (let ((p (promise)))
    (dotimes (i 10)
      (fulfill p (random 100))
      (format t "~d~%" (force p)))))
~~~

Которая выдает:

~~~lisp
LPARALLEL-USER> (multiple-fulfilling)
15
15
15
15
15
15
15
15
15
15
NIL
~~~

Так чем же будущее(future) отличается от обещания(promise)?

`lparallel:future` - это просто обещание, которое выполняется параллельно, 
и поэтому оно не блокирует основной поток, как при использовании 
`lparallel:promise` по умолчанию. Оно выполняется в собственном потоке 
(конечно, библиотекой lparallel).

Вот простой пример будущего(future):

~~~lisp
(defun test-future ()
  (let ((f (future
             (sleep (random 5))
             (print "Hello from future!"))))
    (loop
       when (fulfilledp f)
       do (return)
       do (sleep (* 0.01 (random 100)))
         (format t "~d~%" (random 100)))
    (format t "~d~%" (force f))))
~~~

И вывод:

~~~lisp
LPARALLEL-USER> (test-future)
5
19
91
11
Hello from future!
NIL
~~~

Объяснение: Это в точности похоже на пример с `promise-with-threads`. 
Однако обратите внимание на два отличия - во-первых, у макроса 
`lparallel:future` есть тело. Это позволяет будущему(future) 
реализоваться! Это означает, что как только тело future будет 
выполнено, `lparallel:fulfilledp` всегда будет возвращать true 
для объекта future.


Во-вторых, само будущее(future) порождается библиотекой в ​​отдельном потоке, 
поэтому он не мешает выполнению текущего потока, в отличие от promises(обещаний), 
как можно увидеть в примере с обещанием с потоками (которому требовался явный 
поток для исполняющего кода, чтобы избежать блокировки текущего потока).


Самым интересным моментом является то, что (даже с точки зрения 
фактической теории, предложенной Дэном Фридманом и другими), 
Future(будущее) концептуально является чем-то, что выполняет 
Promise(обещание). Иными словами, обещание - это контракт о том, 
что некоторое значение будет создана когда-нибудь в будущем, 
и будущее(future) - это именно то «нечто», что выполняет эту работу.

Это означает, что даже при использовании библиотеки lparallel основное 
использование future будет заключаться в выполнении обещания. Это означает, 
что пользователю не нужно делать такие хаки, как обещание с потоками
(promise-with-threads).


Давайте рассмотрим небольшой пример, чтобы продемонстрировать это 
(должен признать, довольно надуманный пример!).

Вот сценарий: мы хотим прочитать число и вычислить его квадрат. Поэтому мы 
перекладываем эту работу на другую функцию и продолжаем свою работу. Когда 
результат будет готов, мы хотим, чтобы он был напечатан на консоли без 
нашего вмешательства.


Вот как выглядит код: 

~~~lisp
;;; Callback example using promises and futures
(defun callback-promise-future-demo ()
  (let* ((p (promise))
         (stream *query-io*)
         (n (progn
              (princ "Enter a number: ")
              (read)))
         (f (future
              (sleep (random 10))
              (fulfill p (* n n))
              (force (future
                       (format stream "Square of ~d = ~d~%" n (force p)))))))
    (loop
       when (fulfilledp f)
       do (return)
       do (sleep (* 0.01 (random 100))))))
~~~

И вывод:

~~~lisp
LPARALLEL-USER> (callback-promise-future-demo)
Enter a number: 19
Square of 19 = 361
NIL
~~~

Объяснение: Хорошо, поэтому сначала мы создаем обещание для хранения 
квадрата значения, когда оно будет сгенерировано. Это объект p. Входное 
значение сохраняется в локальной переменной n.

Затем мы создаем объект будущее(future) f. Это future просто возводит в 
квадрат входное значение и выполняет обещание(promise) с этим значением. 
Наконец, поскольку мы хотим напечатать вывод в свое время, мы принудительно 
используем анонимный future, который просто печатает строку вывода, 
как показано.

Обратите внимание, что это очень похоже на ситуацию в такой среде, 
как Node, где мы передаем функции обратного вызова другим функциям с 
пониманием того, что обратный вызов будет вызываться, когда вызванная 
функция завершит свою работу.


Наконец, обратите внимание, что следующий фрагмент все еще в порядке 
(даже если он использует блокирующий вызов `lparallel:force`, потому 
что он находится в отдельном потоке): 

~~~lisp
(force (future
(format stream "Square of ~d = ~d~%" n (force p))))
~~~

Подводя итог, можно сказать, что общая идиома использования такова: **определять 
объекты, которые будут содержать результаты асинхронных вычислений в обещаниях, 
и использовать будущее(future) для выполнения этих обещаний**.



### Использование родственных(cognates) функций - параллельных эквивалентов двойников Common Lisp

Возможно, родственные функции являются смыслом существования библиотеки 
lparallel. Эти конструкции действительно обеспечивают параллелизм в lparallel. 
Однако обратите внимание, что большинство (если не все) из этих конструкций 
построены на основе будущего(futures) и обещаний(promises).

Короче говоря, cognates(родственные) функции - это просто функции, 
которые должны быть параллельными эквивалентами своих аналогов в 
Common Lisp. Однако есть несколько дополнительных параллельных родственных 
функций, у которых нет эквивалентов Common Lisp.


На данном этапе важно знать, что родственные функции бывают двух основных видов: 

-    Конструкции для сильно-дробленого(fine-grained) параллелизма: 
     `defpun`, `plet`, `plet-if`, и т. Д.
-    Явные функции и макросы для выполнения параллельных операций - 
    `pmap`, `preduce`, `psort`, `pdotimes` и т. д.

В первом случае у нас нет явного контроля над самими операциями. 
Мы в основном полагаемся на то, что сама библиотека будет оптимизировать
и распараллеливать формы, насколько это возможно. В этом посте 
мы сосредоточимся на второй категории родственных функций.

Возьмем, к примеру, родственную функцию `lparallel:pmap` точно так же, 
как эквивалент Common Lisp, `map`, но она выполняется параллельно. 
Продемонстрируем это на примере.

Предположим, у нас есть список случайных строк длиной от 3 до 10, 
и мы хотим собрать их длины в векторе.

Давайте сначала настроим вспомогательные функции, которые будут генерировать случайные строки: 

~~~lisp
(defvar *chars*
  (remove-duplicates
   (sort
    (loop for c across "The quick brown fox jumps over the lazy dog"
       when (alpha-char-p c)
       collect (char-downcase c))
    #'char<)))

(defun get-random-strings (&optional (count 100000))
  "generate random strings between lengths 3 and 10"
  (loop repeat count
     collect
       (concatenate 'string  (loop repeat (+ 3 (random 8))
                           collect (nth (random 26) *chars*)))))
~~~

А вот как может выглядеть версия решения с map Common Lisp: 

~~~lisp
;;; map demo
(defun test-map ()
  (map 'vector #'length (get-random-strings 100)))
~~~

И давайте проведем тестовый запуск: 

~~~lisp
LPARALLEL-USER> (test-map)
#(7 5 10 8 7 5 3 4 4 10)
~~~

А вот эквивалент `lparallel:pmap`: 

~~~lisp
;;;pmap demo
(defun test-pmap ()
  (pmap 'vector #'length (get-random-strings 100)))
~~~

которая производит:

~~~lisp
LPARALLEL-USER> (test-pmap)
#(8 7 6 7 6 4 5 6 5 7)
LPARALLEL-USER>
~~~

Как вы можете видеть из определений test-map и test-pmap, 
синтаксис функций `lparallel:map` и `lparallel:pmap` точно такой же 
(ну, почти - `lparallel:pmap` имеет еще несколько дополнительных 
аргументов).

Некоторые полезные родственные функции и макросы (все они являются 
функциями, если они не отмечены так явно. Обратите внимание, что 
родственных функций довольно много, и я выбрал несколько, чтобы 
попытаться представить каждую категорию на примере:


#### lparallel:pmap: параллельная версия map.

Обратите внимание, что все функции сопоставления/mapping (`lparallel:pmap`,
**lparallel:pmapc**,`lparallel:pmapcar` и т. Д.) Принимают два специальных 
аргумента ключевого слова.
- `:size`, определяющий количество элементов входной последовательности(ей) 
для обработки, и
- `:parts` указывающие количество параллельных частей, на которые нужно 
разделить последовательность(и).

~~~lisp
    ;;; pmap - function
    (defun test-pmap ()
      (let ((numbers (loop for i below 10
                        collect i)))
        (pmap 'vector #'(lambda (x)
                          (* x x))
              :parts (length numbers)
              numbers)))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-pmap)

    #(0 1 4 9 16 25 36 49 64 81)
~~~

#### lparallel:por: параллельная версия или.

Поведение таково, что она возвращает первый элемент, отличный от nil, 
среди своих аргументов. Однако из-за параллельного характера этого 
макроса этот элемент меняется. 

~~~lisp
    ;;; por - macro
    (defun test-por ()
      (let ((a 100)
            (b 200)
            (c nil)
            (d 300))
        (por a b c d)))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (dotimes (i 10)
                      (print (test-por)))

    300
    300
    100
    100
    100
    300
    100
    100
    100
    100
    NIL
~~~

В случае обычного оператора  or он всегда возвращал бы первый элемент, 
отличный от nil, а именно. 100.

#### lparallel:pdotimes: параллельная версия dotimes.

Обратите внимание, что этот макрос также принимает необязательный аргумент `:parts`.

~~~lisp
    ;;; pdotimes - macro
    (defun test-pdotimes ()
      (pdotimes (i 5)
        (declare (ignore i))
        (print (random 100))))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-pdotimes)

    39
    29
    81
    42
    56
    NIL
~~~

####  lparallel:pfuncall: параллельная версия funcall.

~~~lisp
    ;;; pfuncall - macro
    (defun test-pfuncall ()
      (pfuncall #'* 1 2 3 4 5))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-pfuncall)

    120
~~~

####    lparallel:preduce: параллельная версия reduce.

Эта очень важная функция также принимает два необязательных аргумента 
ключевого слова: `:parts` (то же значение, что и объяснено) и `:recurse`. 
Если: `:recurse` не равен нулю, она рекурсивно применяет `lparallel:preduce` 
к своим аргументам, в противном случае по умолчанию используется reduce. 

~~~lisp
    ;;; preduce - function
    (defun test-preduce ()
      (let ((numbers (loop for i from 1 to 100
                        collect i)))
        (preduce #'+
                 numbers
                 :parts (length numbers)
                 :recurse t)))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-preduce)

    5050
~~~

####    lparallel:premove-if-not: параллельная версия remove-if-not.

По сути, это эквивалентно «filter/фильтру» на языке функционального программирования. 

~~~lisp
    ;;; premove-if-not
    (defun test-premove-if-not ()
      (let ((numbers (loop for i from 1 to 100
                        collect i)))
        (premove-if-not #'evenp numbers)))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-premove-if-not)

    (2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54
     56 58 60 62 64 66 68 70 72 74 76 78 80 82 84 86 88 90 92 94 96 98 100)
~~~

####    lparallel:pevery: параллельная версия  every.

~~~lisp
    ;;; pevery - function
    (defun test-pevery ()
      (let ((numbers (loop for i from 1 to 100
                        collect i)))
        (list (pevery #'evenp numbers)
              (pevery #'integerp numbers))))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-pevery)

    (NIL T)
~~~

В этом примере мы выполняем две проверки: во-первых, все ли числа 
в диапазоне [1,100] четны, а во-вторых, все ли числа в одном диапазоне 
являются целыми числами. 

#### lparallel:count: параллельная версия count.

~~~lisp
    ;;; pcount - function
    (defun test-pcount ()
      (let ((chars "The quick brown fox jumps over the lazy dog"))
        (pcount #\e chars)))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-pcount)

    3
~~~

####    lparallel:psort: параллельная версия sort.

~~~lisp
    ;;; psort - function
    (defstruct person
      name
      age)

    (defun test-psort ()
      (let* ((names (list "Rich" "Peter" "Sybil" "Basil" "Candy" "Slava" "Olga"))
             (people (loop for name in names
                        collect (make-person :name name :age (+ (random 20) 20)))))
        (print "Before sorting...")
        (print people)
        (fresh-line)
        (print "After sorting...")
        (psort
         people
         #'(lambda (x y)
             (< (person-age x)
                (person-age y)))
         :test #'=)))
~~~

Пробный прогон: 

~~~lisp
    LPARALLEL-USER> (test-psort)

    "Before sorting..."
    (#S(PERSON :NAME "Rich" :AGE 38) #S(PERSON :NAME "Peter" :AGE 24)
     #S(PERSON :NAME "Sybil" :AGE 20) #S(PERSON :NAME "Basil" :AGE 22)
     #S(PERSON :NAME "Candy" :AGE 23) #S(PERSON :NAME "Slava" :AGE 37)
     #S(PERSON :NAME "Olga" :AGE 33))

    "After sorting..."
    (#S(PERSON :NAME "Sybil" :AGE 20) #S(PERSON :NAME "Basil" :AGE 22)
     #S(PERSON :NAME "Candy" :AGE 23) #S(PERSON :NAME "Peter" :AGE 24)
     #S(PERSON :NAME "Olga" :AGE 33) #S(PERSON :NAME "Slava" :AGE 37)
     #S(PERSON :NAME "Rich" :AGE 38))
~~~

В этом примере мы сначала определяем структурный тип person для 
хранения информации о людях. Затем мы создаем список из 7 человек 
со случайным образом сгенерированным возрастом (от 20 до 39). 
Наконец, мы сортируем их по возрасту в неубывающем порядке. 

### Обработка Ошибок

Чтобы узнать, как lparallel обрабатывает ошибки (подсказка: с 
`lparallel:task-handler-bind`), прочтите
[https://z0ltan.wordpress.com/2016/09/10/basic-concurrency-and-parallelism-in-common-lisp-part-4b-parallelism-using-lparallel-error-handling/](https://z0ltan.wordpress.com/2016/09/10/basic-concurrency-and-parallelism-in-common-lisp-part-4b-parallelism-using-lparallel-error-handling/).

## Мониторинг и управление потоками с помощью Slime 

**M-x slime-list-threads** (вы также можете получить к нему доступ 
через *slime-selector*, ярлык **t**) будет перечислять запущенные 
потоки по их именам и их статусам.


Поток в текущей строке можно убить с помощью **k**, или, если нужно убить 
много потоков, можно выбрать несколько строк, и **k** уничтожит все 
потоки в выбранной области.

**g** обновит список потоков, но когда у вас много запускаемых и 
останавливающихся потоков, может быть слишком громоздко всегда нажимать **g**, 
поэтому есть переменная `slime-threads-update-interval`, когда установлено 
число X, список потоков будет будут автоматически обновляться каждые X секунд, 
разумным значением будет 0.5.

Thanks to [Slime tips](https://slime-tips.tumblr.com/).

## Ссылки

Конечно, существует гораздо больше функций, объектов и идиоматических 
способов выполнения параллельных вычислений с использованием библиотеки 
lparallel. Этот пост даже поверхностно об этом не говорит. Однако здесь 
подробно демонстрируется общий процесс работы, и для дальнейшего чтения 
вам могут быть полезны следующие ресурсы: 

- [The official homepage of the lparallel library, including documentation](https://lparallel.org/)
- [The Common Lisp Hyperspec](https://www.lispworks.com/documentation/HyperSpec/Front/), and, of course
- Your Common Lisp implementationâs
  manual. [For SBCL, here is a link to the official manual](http://www.sbcl.org/manual/)
- [Common Lisp recipes](http://weitz.de/cl-recipes/) by the venerable Edi Weitz.
- more concurrency and threading libraries on the [Awesome-cl#parallelism-and-concurrency](https://github.com/CodyReichert/awesome-cl#parallelism-and-concurrency) list.