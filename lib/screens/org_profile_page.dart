import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elbi_donation_system/components/header_with_pic.dart';
import 'package:elbi_donation_system/components/main_drawer.dart';
import 'package:elbi_donation_system/components/rounded_image.dart';
import 'package:elbi_donation_system/components/square_image.dart';
import 'package:elbi_donation_system/components/title_detail.dart';
import 'package:elbi_donation_system/components/title_detail_list.dart';
import 'package:elbi_donation_system/components/upload_helper.dart';
import 'package:elbi_donation_system/models/donation_drive_model.dart';
import 'package:elbi_donation_system/models/route_model.dart';
import 'package:elbi_donation_system/models/user_model.dart';
import 'package:elbi_donation_system/providers/auth_provider.dart';
import 'package:elbi_donation_system/providers/donation_drive_provider.dart';
import 'package:elbi_donation_system/providers/dummy_providers/user_list_provider.dart';
import 'package:elbi_donation_system/providers/user_provider.dart';
import 'package:elbi_donation_system/screens/donation_drive_list_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrgProfilePage extends StatefulWidget {
  const OrgProfilePage({super.key});

  @override
  State<OrgProfilePage> createState() => _OrgProfilePageState();
}

class _OrgProfilePageState extends State<OrgProfilePage> {
  @override
  Widget build(BuildContext context) {
    User authUser = context.watch<AuthProvider>().currentUser;
    User user = context.watch<UserProvider>().selected;

    Row actionButtons;
    if (authUser.role == User.admin && user.isApproved == false) {
      actionButtons = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.id!)
                    .update({'isApproved': true});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${user.name} approved"),
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text("Approve")),
          TextButton.icon(
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false)
                  .deleteUser(user.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${user.name} disapproved and deleted"),
                ),
              );
            },
            icon: const Icon(Icons.delete_rounded),
            label: const Text("Disapprove"),
            style: ButtonStyle(
                foregroundColor: MaterialStatePropertyAll(
                    Theme.of(context).colorScheme.error)),
          )
        ],
      );
    } else if (authUser.role == User.organization) {
      actionButtons = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text("Open for Donation"),
          Switch(
              inactiveTrackColor: Theme.of(context).disabledColor,
              activeColor: Theme.of(context).primaryColor,
              value: authUser.isOpenForDonation!,
              onChanged: (e) {
                Map<String, dynamic> userMap = authUser.toJson();
                setState(() {
                  userMap["isOpenForDonation"] =
                      authUser.isOpenForDonation! ? false : true;
                });
                context.read<AuthProvider>().updateUser(User.fromJson(userMap));
              })
        ],
      );
    } else {
      if (user.isOpenForDonation!) {
        actionButtons = const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                "Open for Donation",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      } else {
        actionButtons = const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                "Closed for Donation",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }
    }

    Widget proofList;
    if (authUser.role == User.admin || authUser.role == User.organization) {
      proofList = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Proofs of Legitimacy",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3),
              itemCount: user.proofsOfLegitimacy?.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                    padding: const EdgeInsets.all(5.00),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: SquareImage(
                            source: user.proofsOfLegitimacy![index],
                            size: 80)));
              }),
        ],
      );
    } else {
      proofList = const SizedBox.shrink();
    }

    Stream<QuerySnapshot> donationDrivesStream =
        context.watch<DonationDriveProvider>().donationDrives;

    Widget donationDrives;
    donationDrives = Expanded(
        child: StreamBuilder(
      stream: donationDrivesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("Error encountered! ${snapshot.error}"),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (!snapshot.hasData) {
          return const Center(
            child: Text("No Donations Drives Found"),
          );
        }

        // Filter donations Drives by donorId
        var filteredDonationDrives = snapshot.data!.docs.where((doc) {
          Map<String, dynamic> docMap = doc.data() as Map<String, dynamic>;
          docMap["id"] = doc.id;
          DonationDrive donationDrive = DonationDrive.fromJson(docMap);
          return donationDrive.organizationId == user.id;
        }).toList();

        if (filteredDonationDrives.isEmpty) {
          return const Center(
            child: Text("This organization doesn't have a donation drive yet"),
          );
        }

        return ListView.builder(
            itemCount: filteredDonationDrives.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> mapData =
                  filteredDonationDrives[index].data() as Map<String, dynamic>;
              mapData["id"] = filteredDonationDrives[index].id;
              DonationDrive donationDrive = DonationDrive.fromJson(mapData);
              return ListTile(
                leading:
                    RoundedImage(source: donationDrive.photos![0], size: 50),
                title: Text(donationDrive.name),
                subtitle: Text(donationDrive.description),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () async {
                    context
                        .read<DonationDriveProvider>()
                        .changeSelectedDonationDrive(donationDrive);
                    context
                        .read<DonationDriveProvider>()
                        .changeSelectedDonationDriveUser(await context
                            .read<UserProvider>()
                            .fetchUserById(donationDrive.organizationId));
                    Navigator.pushNamed(context, "/donation-drive-details");
                  },
                ),
              );
            });
      },
    ));

    return Scaffold(
        appBar: AppBar(
          title: Text(user.name),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              HeaderWithPic(
                imageUrl: user.profilePhoto ?? "",
                title: user.name,
                subtitle: user.username,
                description: user.about ?? "No tagline to display...",
              ),
              TitleDetailList(title: "Address", detailList: user.address),
              TitleDetail(
                title: "Contact Number",
                detail: user.contactNo,
              ),
              proofList,
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  "Donation Drives",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              donationDrives,
              actionButtons,
            ],
          ),
        ));
  }
}
